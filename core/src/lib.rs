use std::env;
use eframe::egui::{self, CentralPanel};
use tokio::sync::mpsc;
use tokio::sync::mpsc::Receiver;
use dotenv::dotenv;

pub struct MyApp {
    text: String,
    pub rx: Option<Receiver<String>>,
}

impl Default for MyApp {
    fn default() -> Self {
        dotenv().ok();

        let (tx, rx) = mpsc::channel(1);

        std::thread::spawn(move || {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async {
                let api_key = env::var("API_KEY").expect("API_KEY was not set");
                match reqwest::Client::new()
                    .get("https://mycelia.nel.re/api/messages")
                    .header("Authorization", format!("Bearer {api_key}"))
                    .send()
                    .await
                {
                    Ok(response) => {
                        if let Ok(body) = response.text().await {
                            let _ = tx.send(body).await;
                        }
                    }
                    Err(e) => {
                        eprintln!("Request error: {}", e);
                        let _ = tx.send(format!("Error: {}", e)).await;
                    }
                }
            });
        });

        Self {
            text: "Loading...".to_string(),
            rx: Some(rx),
        }
    }
}

impl eframe::App for MyApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        if let Some(rx) = &mut self.rx {
            match rx.try_recv() {
                Ok(message) => {
                    self.text = message;
                }
                Err(_) => {}
            }
        }

        CentralPanel::default().show(ctx, |ui| {
            ui.label(self.text.clone());
        });
    }
}
