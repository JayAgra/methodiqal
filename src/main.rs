use actix_governor::{Governor, GovernorConfigBuilder};
use actix_identity::{CookieIdentityPolicy, Identity, IdentityService};
use actix_session::{config::PersistentSession, SessionMiddleware};
use actix_web::{
    cookie::Key,
    dev::Payload,
    error,
    http::header::ContentType,
    middleware::{self, DefaultHeaders},
    web, App, Error as AWError, FromRequest, HttpRequest, HttpResponse, HttpServer, Responder,
};
use dotenv::dotenv;
use openssl::{ssl::{SslAcceptor, SslFiletype, SslMethod}};
use r2d2_sqlite::{self, SqliteConnectionManager};
use regex::Regex;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::{collections::HashMap, env, fs, io, pin::Pin, sync::RwLock, time::{SystemTime, UNIX_EPOCH}, path::PathBuf};

mod auth;
mod db_auth;
mod session;

// hashmap containing user session IDs
#[derive(Serialize, Deserialize, Default, Clone)]
struct Sessions {
    user_map: HashMap<String, db_auth::User>,
}

// gets a user object from requests. needed for db_auth::User param in handlers
impl FromRequest for db_auth::User {
    type Error = actix_web::Error;
    type Future = Pin<Box<dyn futures_util::Future<Output = Result<db_auth::User, Self::Error>>>>;

    fn from_request(req: &HttpRequest, payload: &mut Payload) -> Self::Future {
        let fut = Identity::from_request(req, payload);
        let session: Option<&web::Data<RwLock<Sessions>>> = req.app_data();
        if session.is_none() {
            return Box::pin(async { Err(error::ErrorUnauthorized("{\"status\": \"unauthorized\"}")) });
        }
        let session = session.unwrap().clone();
        Box::pin(async move {
            if let Some(identity) = fut.await?.identity() {
                if let Some(user) = session.read().unwrap().user_map.get(&identity).map(|x| x.clone()) {
                    return Ok(user);
                }
            };
            Err(error::ErrorUnauthorized("{\"status\": \"unauthorized\"}"))
        })
    }
}

struct Databases {
    auth: db_auth::Pool,
}

fn get_secret_key() -> Key {
    Key::generate()
}

async fn auth_post_create(db: web::Data<Databases>, data: web::Json<auth::LoginForm>) -> impl Responder {
    auth::create_account(&db.auth, data).await
}

// login endpoint
async fn auth_post_login(db: web::Data<Databases>, session: web::Data<RwLock<Sessions>>, identity: Identity, data: web::Json<auth::LoginForm>) -> impl Responder {
    auth::login(&db.auth, session, identity, data).await
}

// delete account endpoint
async fn auth_post_delete(db: web::Data<Databases>, data: web::Json<auth::LoginForm>, session: web::Data<RwLock<crate::Sessions>>, identity: Identity) -> Result<HttpResponse, AWError> {
    Ok(auth::delete_account(&db.auth, data, session, identity).await?)
}

// destroy session endpoint
async fn auth_get_logout(session: web::Data<RwLock<Sessions>>, identity: Identity) -> impl Responder {
    auth::logout(session, identity).await
}

// get to confirm session status and obtain current user id
async fn auth_get_whoami(db: web::Data<Databases>, user: db_auth::User) -> Result<HttpResponse, AWError> {
    Ok(HttpResponse::Ok()
        .insert_header(("Cache-Control", "no-cache"))
        .json(db_auth::get_user_username(&db.auth, user.username).await?))
}

#[derive(Deserialize)]
struct IncomingChatGptRequest {
    prompt: String
}

// ChatGPT API forwarding

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

async fn chatgpt_handler(req: web::Json<IncomingChatGptRequest>) -> HttpResponse {
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

    // hashmap w: web::Data<RwLock<Sessions>>ith user sessions in it
    let sessions: web::Data<RwLock<Sessions>> = web::Data::new(RwLock::new(Sessions { user_map: HashMap::new() }));

    // auth database connection
    let auth_db_manager = SqliteConnectionManager::file("data_auth.db");
    let auth_db_pool = db_auth::Pool::new(auth_db_manager).unwrap();
    let auth_db_connection = auth_db_pool.get().expect("auth db: connection failed");
    auth_db_connection.execute_batch("PRAGMA journal_mode=WAL;").expect("auth db: WAL failed");
    drop(auth_db_connection);

    // man database connection
    let main_db_manager = SqliteConnectionManager::file("data_main.db");
    let main_db_pool = db_auth::Pool::new(main_db_manager).unwrap();
    let main_db_connection = main_db_pool.get().expect("main db: connection failed");
    main_db_connection.execute_batch("PRAGMA journal_mode=WAL;").expect("main db: WAL failed");
    drop(main_db_connection);

    let secret_key = get_secret_key();

    // ratelimiting with governor
    let governor_conf = GovernorConfigBuilder::default()
        // these may be a lil high but whatever
        .per_nanosecond(100)
        .burst_size(25000)
        .finish()
        .unwrap();

    /*
     *  generate a self-signed certificate for localhost (run from macsvc directory):
     *  openssl req -x509 -newkey rsa:4096 -nodes -keyout ./ssl/key.pem -out ./ssl/cert.pem -days 365 -subj '/CN=localhost'
     */
    // create ssl builder for tls config
    let mut builder = SslAcceptor::mozilla_intermediate(SslMethod::tls()).unwrap();
    builder.set_private_key_file("./ssl/key.pem", SslFiletype::PEM).unwrap();
    builder.set_certificate_chain_file("./ssl/cert.pem").unwrap();

    // config done. now, create the new HttpServer
    log::info!("[OK] starting M-A Central Services (macsvc) on port 443 and 80");

    HttpServer::new(move || {
        // other static directories
        App::new()
            // add databases to app data
            .app_data(web::Data::new(Databases {
                auth: auth_db_pool.clone(),
            }))
            // add sessions to app data
            .app_data(sessions.clone())
            // use governor ratelimiting as middleware
            .wrap(Governor::new(&governor_conf))
            // ident service
            .wrap(IdentityService::new(
                CookieIdentityPolicy::new(&[0; 32])
                    .name("ma_central")
                    .max_age_secs(actix_web::cookie::time::Duration::weeks(2).whole_seconds())
                    .secure(false),
            ))
            // logging middleware
            .wrap(middleware::Logger::default())
            // session middleware
            .wrap(
                SessionMiddleware::builder(session::MemorySession, secret_key.clone())
                    .cookie_name("ma_central-ms".to_string())
                    .cookie_http_only(true)
                    .cookie_secure(false)
                    .session_lifecycle(
                        PersistentSession::default()
                            .session_ttl(actix_web::cookie::time::Duration::weeks(2)),
                    )
                    .build(),
            )
            // default headers for caching. overridden on most all api endpoints
            .wrap(
                DefaultHeaders::new()
                    .add(("Cache-Control", "public, max-age=23328000"))
                    .add(("X-macsvc", "1.2.0")),
            )
            .service(
                web::resource("/apple-app-site-association")
                    .route(web::get().to(misc_apple_app_site_association)),
            )
            .service(
                web::resource("/api/v1/auth/logout")
                    .route(web::get().to(auth_get_logout))
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
    .bind_openssl(format!("{}:443", env::var("HOSTNAME").unwrap_or_else(|_| "localhost".to_string())), builder)?
    .bind((env::var("HOSTNAME").unwrap_or_else(|_| "localhost".to_string()), 80))?
    .workers(8)
    .run()
    .await
}
