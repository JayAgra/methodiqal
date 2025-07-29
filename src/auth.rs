use actix_http::StatusCode;
use actix_web::{web, HttpResponse, Responder};
use argon2::{
    password_hash::{PasswordHash, PasswordVerifier},
    Argon2,
};
use regex::Regex;
use serde::{Deserialize, Serialize};

use crate::db_auth;
use crate::jwt;

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct LoginForm {
    username: String,
    password: String,
}

pub async fn create_account(pool: web::Data<sqlx::MySqlPool>, create_form: web::Json<LoginForm>) -> impl Responder + use<> {
    // check password length is between 8 and 32, inclusive
    if create_form.password.len() >= 8 && create_form.password.len() <= 64 {
        // check if user is a sketchy motherfucker
        let regex = Regex::new(r"^[a-z0-9A-Z- ~!@#$%^&*()=+/\_[_]{}|?.,]{3,64}$").unwrap();
        if !regex.is_match(&create_form.username) || !regex.is_match(&create_form.password) {
            return HttpResponse::BadRequest()
                .status(StatusCode::from_u16(400).unwrap())
                .insert_header(("Cache-Control", "no-cache"))
                .body("{\"token\": \"bad_characters\"}");
        }
        // check if username is taken
        let target_user_temp: Result<db_auth::User, sqlx::Error> = db_auth::get_user_username(pool.clone(), create_form.username.clone()).await;
        if target_user_temp.is_ok() {
            return HttpResponse::BadRequest()
                .status(StatusCode::from_u16(409).unwrap())
                .insert_header(("Cache-Control", "no-cache"))
                .body("{\"token\": \"bad_username\"}");
        } else {
            // insert into database
            let user_temp: Result<db_auth::User, sqlx::Error> = db_auth::create_user(
                pool,
                create_form.username.clone(),
                create_form.password.clone(),
            )
            .await;
            // send final success/failure for creation
            if user_temp.is_err() {
                return HttpResponse::BadRequest()
                    .status(StatusCode::from_u16(500).unwrap())
                    .insert_header(("Cache-Control", "no-cache"))
                    .body("{\"token\": \"bad_creation\"}");
            } else {
                let user = user_temp.unwrap();
                let token: String= jwt::create_jwt(user).unwrap_or("bad_token".to_string());
                return HttpResponse::Ok()
                    .status(StatusCode::from_u16(200).unwrap())
                    .insert_header(("Cache-Control", "no-cache"))
                    .body(format!("{{\"token\": \"{}\"}}", token));
            }
        }
    } else {
        return HttpResponse::BadRequest()
            .status(StatusCode::from_u16(413).unwrap())
            .insert_header(("Cache-Control", "no-cache"))
            .body("{\"token\": \"bad_password\"}");
    }
}

pub async fn login(pool: web::Data<sqlx::MySqlPool>, login_form: web::Json<LoginForm>) -> impl Responder + use<> {
    // try to get target user from database
    let target_user_temp: Result<db_auth::User, sqlx::Error> = db_auth::get_user_username(pool, login_form.username.clone()).await;
    if target_user_temp.is_err() {
        // query error, send failure response
        return HttpResponse::BadRequest()
            .status(StatusCode::from_u16(400).unwrap())
            .insert_header(("Cache-Control", "no-cache"))
            .body("{\"token\": \"bad_s1\"}");
    }
    // query was OK, unwrap and set to target_user
    let target_user = target_user_temp.unwrap();

    // ensure the target user id exists
    if target_user.id != 0 {
        // parse the hash of the user from the database
        let parsed_hash = PasswordHash::new(&target_user.pass_hash);
        // if error in parsing hash, send failure response
        if parsed_hash.is_err() {
            // could not parse hash, send failure
            return HttpResponse::BadRequest()
                .status(StatusCode::from_u16(400).unwrap())
                .insert_header(("Cache-Control", "no-cache"))
                .body("{\"token\": \"bad_s2\"}");
        }
        // check that the provided password's hash is equal to the correct password's hash
        if Argon2::default()
            .verify_password(login_form.password.as_bytes(), &parsed_hash.unwrap())
            .is_ok()
        {
            /* CREATE JWT */
            let token: String= jwt::create_jwt(target_user).unwrap_or("bad_s5".to_string());
            // send generic success response
            return HttpResponse::Ok()
                .status(StatusCode::from_u16(200).unwrap())
                .insert_header(("Cache-Control", "no-cache"))
                .body(format!("{{\"token\": \"{}\"}}", token));
        } else {
            // bad password, send 400
            return HttpResponse::BadRequest()
                .status(StatusCode::from_u16(400).unwrap())
                .insert_header(("Cache-Control", "no-cache"))
                .body("{\"token\": \"bad_s3\"}");
        }
    } else {
        // target user id is zero, send 400
        return HttpResponse::BadRequest()
            .status(StatusCode::from_u16(400).unwrap())
            .insert_header(("Cache-Control", "no-cache"))
            .body("{\"token\": \"bad_s4\"}");
    }
}

pub async fn delete_account(pool: web::Data<sqlx::MySqlPool>, login_form: web::Json<LoginForm>) -> impl Responder {
    let target_user_temp: Result<db_auth::User, sqlx::Error> = db_auth::get_user_username(pool.clone(), login_form.username.clone()).await;
    if target_user_temp.is_err() {
        return HttpResponse::BadRequest()
            .status(StatusCode::from_u16(400).unwrap())
            .insert_header(("Cache-Control", "no-cache"))
            .body("{\"status\": \"bad\"}");
    }
    let target_user = target_user_temp.unwrap();
    if target_user.id != 0 {
        let parsed_hash = PasswordHash::new(&target_user.pass_hash);
        if parsed_hash.is_err() {
            return HttpResponse::BadRequest()
                .status(StatusCode::from_u16(400).unwrap())
                .insert_header(("Cache-Control", "no-cache"))
                .body("{\"status\": \"bad\"}");
        }
        if Argon2::default()
            .verify_password(login_form.password.as_bytes(), &parsed_hash.unwrap())
            .is_ok()
        {
            db_auth::delete_user(pool, target_user.id).await
        } else {
            HttpResponse::BadRequest()
                .status(StatusCode::from_u16(400).unwrap())
                .insert_header(("Cache-Control", "no-cache"))
                .body("{\"status\": \"bad\"}")
        }
    } else {
        HttpResponse::BadRequest()
            .status(StatusCode::from_u16(400).unwrap())
            .insert_header(("Cache-Control", "no-cache"))
            .body("{\"status\": \"bad\"}")
    }
}