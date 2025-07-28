use actix_web::{error, web, Error};
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};
use rusqlite::{params, Statement};
use serde::{Deserialize, Serialize};
use std::str;

pub type Pool = r2d2::Pool<r2d2_sqlite::SqliteConnectionManager>;
pub type Connection = r2d2::PooledConnection<r2d2_sqlite::SqliteConnectionManager>;
type UserQueryResult = Result<Vec<User>, rusqlite::Error>;

#[derive(Serialize, Deserialize, Clone)]
pub struct User {
    pub id: i64,
    pub username: String,
    pub pro_until: i64,
    pub pass_hash: String,
}

pub async fn create_user(pool: &Pool, username: String, password: String) -> Result<User, Error> {
    let pool = pool.clone();
    let conn = web::block(move || pool.get()).await?.map_err(error::ErrorInternalServerError)?;
    web::block(move || {
        let generated_salt = SaltString::generate(&mut OsRng);
        // argon2id v19
        let argon2ins = Argon2::default();
        // hash into phc string
        let hashed_password = argon2ins.hash_password(password.as_bytes(), &generated_salt);
        if hashed_password.is_err() {
            return Ok(User {
                id: 0,
                username,
                pro_until: 0,
                pass_hash: "".to_string()
            })
            .map_err(rusqlite::Error::NulError);
        }
        create_user_entry(conn, username, hashed_password.unwrap().to_string())
    })
    .await?
    .map_err(error::ErrorInternalServerError)
}

pub async fn get_user_username(pool: &Pool, username: String) -> Result<User, Error> {
    let pool = pool.clone();

    let conn = web::block(move || pool.get()).await?.map_err(error::ErrorInternalServerError)?;

    web::block(move || get_user_username_entry(conn, username))
        .await?
        .map_err(error::ErrorInternalServerError)
}

fn get_user_username_entry(conn: Connection, id: String) -> Result<User, rusqlite::Error> {
    let mut stmt = conn.prepare("SELECT * FROM users WHERE username=?1;")?;
    stmt.query_row([id], |row| {
        Ok(User {
            id: row.get(0)?,
            username: row.get(1)?,
            pass_hash: row.get(2)?,
            pro_until: row.get(3)?
        })
    })
}

fn create_user_entry(conn: Connection, username: String, password_hash: String) -> Result<User, rusqlite::Error> {
    let mut stmt = conn.prepare("INSERT INTO users (username, pro_until, pass_hash) VALUES (?, 0, ?);")?;
    let mut new_user = User {
        id: 0,
        username,
        pro_until: 0,
        pass_hash: password_hash
    };
    stmt.execute(params![new_user.username, new_user.pass_hash])?;
    new_user.id = conn.last_insert_rowid();
    Ok(new_user)
}

pub async fn execute_manage_user(pool: &Pool, params: [String; 1]) -> Result<String, Error> {
    let pool = pool.clone();

    let conn = web::block(move || pool.get()).await?.map_err(error::ErrorInternalServerError)?;

    web::block(move || {
        manage_delete_user(conn, params)
    })
    .await?
    .map_err(error::ErrorInternalServerError)
}

fn manage_delete_user(connection: Connection, params: [String; 1]) -> Result<String, rusqlite::Error> {
    let stmt = connection.prepare("DELETE FROM users WHERE id=?1;")?;
    execute_manage_action(stmt, params)
}

fn execute_manage_action(mut statement: Statement, params: [String; 1]) -> Result<String, rusqlite::Error> {
    if statement.execute(params).is_ok() {
        Ok("{\"status\":3206}".to_string())
    } else {
        Ok("{\"status\":8002}".to_string())
    }
}
