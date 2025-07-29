use actix_web::{dev::{Service, Transform, ServiceRequest}, Error, HttpMessage};
use chrono::{Utc, Duration};
use futures_util::future::{ok, Ready, LocalBoxFuture};
use serde::{Serialize, Deserialize};
use std::env;
use jsonwebtoken::{encode, Header, EncodingKey, decode, DecodingKey, Validation};

use crate::db_auth;

#[derive(Debug, Serialize, Clone, Deserialize)]
pub struct Claims {
    pub sub: u64,
    exp: usize,
}

pub fn create_jwt(user: db_auth::User) -> Result<String, jsonwebtoken::errors::Error> {
    let expiration = Utc::now()
        .checked_add_signed(Duration::days(30))
        .expect("valid timestamp")
        .timestamp() as usize;

    let claims = Claims {
        sub: user.id,
        exp: expiration,
    };

    let secret = env::var("JWT_SECRET").expect("INSECURE_DEFAULT");
    encode(&Header::default(), &claims, &EncodingKey::from_secret(secret.as_bytes()))
}

// Authentication

pub struct Auth;

impl<S, B> Transform<S, ServiceRequest> for Auth
where
    S: Service<ServiceRequest, Response = actix_web::dev::ServiceResponse<B>, Error = Error> + 'static,
    B: 'static,
{
    type Response = actix_web::dev::ServiceResponse<B>;
    type Error = Error;
    type InitError = ();
    type Transform = AuthMiddleware<S>;
    type Future = Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        ok(AuthMiddleware { service })
    }
}

pub struct AuthMiddleware<S> {
    service: S,
}

impl<S, B> Service<ServiceRequest> for AuthMiddleware<S>
where
    S: Service<ServiceRequest, Response = actix_web::dev::ServiceResponse<B>, Error = Error> + 'static,
    B: 'static,
{
    type Response = actix_web::dev::ServiceResponse<B>;
    type Error = Error;
    type Future = LocalBoxFuture<'static, Result<Self::Response, Error>>;

    fn poll_ready(&self, cx: &mut std::task::Context<'_>) -> std::task::Poll<Result<(), Error>> {
        self.service.poll_ready(cx)
    }

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let auth_header = req.headers().get("Authorization").and_then(|hv| hv.to_str().ok());

        if let Some(header_value) = auth_header {
            if header_value.starts_with("Bearer ") {
                let token = header_value.trim_start_matches("Bearer ").trim();
                let secret = env::var("JWT_SECRET").expect("INSECURE_DEFAULT");

                let decoded = decode::<Claims>(
                    token,
                    &DecodingKey::from_secret(secret.as_bytes()),
                    &Validation::default(),
                );

                if let Ok(token_data) = decoded {
                    req.extensions_mut().insert(token_data.claims);
                    let fut = self.service.call(req);
                    return Box::pin(async move { fut.await });
                }
            }
        }

        Box::pin(async {
            Err(actix_web::error::ErrorUnauthorized("Invalid or missing token"))
        })
    }
}