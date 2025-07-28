use actix_governor::{Governor, GovernorConfigBuilder};
use actix_web::{
    http::header::ContentType,
    middleware::{self, DefaultHeaders},
    web, App, Error as AWError, HttpResponse, HttpServer, Responder,
};
use dotenv::dotenv;
use r2d2_sqlite::{self, SqliteConnectionManager};
use regex::Regex;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::{env, io};

mod auth;
mod db_auth;
mod jwt;

struct Databases {
    auth: db_auth::Pool,
}

async fn auth_post_create(db: web::Data<Databases>, data: web::Json<auth::LoginForm>) -> impl Responder {
    auth::create_account(&db.auth, data).await
}

// login endpoint
async fn auth_post_login(db: web::Data<Databases>, data: web::Json<auth::LoginForm>) -> impl Responder {
    auth::login(&db.auth, data).await
}

// delete account endpoint
async fn auth_post_delete(db: web::Data<Databases>, data: web::Json<auth::LoginForm>) -> Result<HttpResponse, AWError> {
    Ok(auth::delete_account(&db.auth, data).await?)
}

// get to confirm session status and obtain current user id
async fn auth_get_whoami(db: web::Data<Databases>, claims: web::ReqData<jwt::Claims>) -> Result<HttpResponse, AWError> {
    Ok(HttpResponse::Ok()
        .insert_header(("Cache-Control", "no-cache"))
        .json(db_auth::get_user_username(&db.auth, claims.into_inner().sub.username).await?))
}

// ChatGPT API forwarding

#[derive(Deserialize)]
struct IncomingChatGptRequest {
    prompt: String
}

#[derive(Serialize)]
struct ChatGptRequest {
    messages: Vec<Message>,
}

impl ChatGptRequest {
    pub fn new(messages: Vec<Message>) -> Self {
        Self { messages }
    }
}

#[derive(Serialize, Deserialize, Clone)]
struct Message {
    role: String,
    content: String,
}

impl Message {
    pub fn new(role: String, content: String) -> Self {
        Self { role, content }
    }
}

async fn chatgpt_handler(req: web::Json<IncomingChatGptRequest>, _claims: web::ReqData<jwt::Claims>) -> HttpResponse {
    let client = Client::new();
    let api_key = env::var("OPENAI_API_KEY").expect("API key not set");

    let re = Regex::new("([\"'`\\[\\]{}()<>])").unwrap();

    let fixed: String = re.replace_all(req.prompt.as_str(), |caps: &regex::Captures| {
        format!("\\{}", &caps[0])
    }).into_owned();

    let full_prompt = format!(
        "\nCourse: Test\nAssignment name: Test\nDue date: 01/01/2026 09:00\nCity: America/New York\n\nAssignment content: \"{}\"",
        fixed
    );

    let response = client
        .post("https://api.openai.com/v1/assistants/asst_7gYNXRWbGdV99qG6Xr4F2aak/messages")
        .bearer_auth(api_key)
        .json(&ChatGptRequest::new( [Message::new("user".to_string(), full_prompt)].to_vec()))
        .send()
        .await;

    match response {
        Ok(res) => {
            if res.status().is_success() {
                let body = res.json::<serde_json::Value>().await.unwrap();
                HttpResponse::Ok().json(body)
            } else {
                HttpResponse::BadRequest().body(res.text().await.unwrap())
            }
        }
        Err(err) => {
            HttpResponse::InternalServerError().body(err.to_string())
        }
    }
}

const APPLE_APP_SITE_ASSOC: &str = "{\"webcredentials\":{\"apps\":[\"D6MFYYVHA8.com.jayagra.ma-central\", \"D6MFYYVHA8.com.jayagra.ma-central-admin\"]}}";
async fn misc_apple_app_site_association() -> Result<HttpResponse, AWError> {
    Ok(HttpResponse::Ok().content_type(ContentType::json()).body(APPLE_APP_SITE_ASSOC))
}

#[actix_web::main]
async fn main() -> io::Result<()> {
    // load environment variables from .env file
    dotenv().ok();

    // auth database connection
    let auth_db_manager = SqliteConnectionManager::file("data_auth.db");
    let auth_db_pool = db_auth::Pool::new(auth_db_manager).unwrap();
    let auth_db_connection = auth_db_pool.get().expect("auth db: connection failed");
    auth_db_connection.execute_batch("PRAGMA journal_mode=WAL;").expect("auth db: WAL failed");
    drop(auth_db_connection);

    // ratelimiting with governor
    let governor_conf = GovernorConfigBuilder::default()
        // these may be a lil high but whatever
        .per_nanosecond(100)
        .burst_size(25000)
        .finish()
        .unwrap();

    // config done. now, create the new HttpServer
    log::info!("[OK] starting methodiqal on port 3003");

    HttpServer::new(move || {
        // other static directories
        App::new()
            // add databases to app data
            .app_data(web::Data::new(Databases {
                auth: auth_db_pool.clone(),
            }))
            // use governor ratelimiting as middleware
            .wrap(Governor::new(&governor_conf))
            // logging middleware
            .wrap(middleware::Logger::default())
            .wrap(jwt::Auth)
            // default headers for caching. overridden on most all api endpoints
            .wrap(
                DefaultHeaders::new()
                    .add(("Cache-Control", "public, max-age=23328000"))
                    .add(("X-methodiqal", "1.0.0")),
            )
            .service(
                web::resource("/apple-app-site-association")
                    .route(web::get().to(misc_apple_app_site_association)),
            )
            .service(
                web::resource("/api/v1/auth/whoami")
                    .route(web::get().to(auth_get_whoami))
            )
            // post
            .service(
                web::resource("/api/v1/auth/create")
                    .route(web::post().to(auth_post_create)),
            )
            .service(
                web::resource("/api/v1/auth/login")
                    .route(web::post().to(auth_post_login)),
            )
            .service(
                web::resource("/api/v1/auth/delete")
                    .route(web::post().to(auth_post_delete)),
            )
            .route(
                "/api/chatgpt", web::post().to(chatgpt_handler)
            )
    })
    .bind("0.0.0.0:3003")?
    .workers(8)
    .run()
    .await
}
