use actix_web::{web, HttpResponse, Responder};
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};
use serde::{Deserialize, Serialize};
use std::str;
use sqlx::FromRow;

#[derive(Serialize, Deserialize, Clone, Debug, FromRow)]
pub struct User {
    pub id: u64,
    pub username: String,
    pub pro_until: u64,
    pub pass_hash: String,
}

pub async fn get_user_username(pool: web::Data<sqlx::MySqlPool>, username: String) -> Result<User, sqlx::Error> {
    let result = sqlx::query_as::<_, User>("SELECT * FROM username WHERE id=?;")
        .bind(username)
        .fetch_one(pool.get_ref())
        .await;
    
    match result {
        Ok(users) => Ok(users),
        Err(e) => Err(e)
    }
}

pub async fn get_user_id(pool: web::Data<sqlx::MySqlPool>, id: u64) -> impl Responder {
    let result = sqlx::query_as::<_, User>("SELECT * FROM users WHERE id=?;")
        .bind(id)
        .fetch_one(pool.get_ref())
        .await;
    
    match result {
        Ok(users) => HttpResponse::Ok().json(users),
        Err(e) => {
            println!("{}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

pub async fn create_user(pool: web::Data<sqlx::MySqlPool>, username: String, password: String) -> Result<User, sqlx::Error> {
    let generated_salt = SaltString::generate(&mut OsRng);
    let argon2ins = Argon2::default();
    let hashed_password = argon2ins.hash_password(password.as_bytes(), &generated_salt);
    if hashed_password.is_err() {
        return Ok(User {
            id: 0,
            username,
            pro_until: 0,
            pass_hash: "".to_string()
        })
    }

    let password_hash = hashed_password.unwrap().to_string();

    let query = sqlx::query("INSERT INTO users (username, pro_until, pass_hash) VALUES (?, 0, ?);")
        .bind(username.clone())
        .bind(password_hash.clone())
        .execute(pool.get_ref())
        .await;

    let mut new_user = User {
        id: 0,
        username,
        pro_until: 0,
        pass_hash: password_hash
    };
    
    match query {
        Ok(result) => {
            new_user.id = result.last_insert_id();
            Ok(new_user)
        },
        Err(e) => {
            println!("{}", e);
            Err(e)
        }
    }
}

pub async fn delete_user(pool: web::Data<sqlx::MySqlPool>, id: u64) -> HttpResponse {
    let result = sqlx::query("DELETE FROM users WHERE id=?;")
        .bind(id)
        .execute(pool.get_ref())
        .await;
    
    match result {
        Ok(_r) => HttpResponse::Ok().finish(),
        Err(_e) => HttpResponse::InternalServerError().finish()
    }
}