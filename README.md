# FitCast – AI-Powered Weather-Based Outfit Recommendation System

[![Flutter](https://img.shields.io/badge/Frontend-Flutter-%2302569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI-%23009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/ML--Core-Python--Scikit--Learn-%233776AB?logo=python)](https://python.org)

## 📝 Overview
**FitCast** is a full-stack, AI-powered mobile application that provides personalized outfit recommendations based on real-time weather conditions, user preferences, target activities, and personal comfort levels. 

Instead of simply displaying standard weather forecasts, the application combines **Machine Learning**, rule-based decision making, weather metrics analysis, and personalized feedback loops to generate practical, intelligent clothing layers tailored to each individual.

This project was developed as a Computer Science Senior Project at the German Jordanian University. The full system documentation can be found in the accompanying report, `SP_Report_AyahSaid.pdf`.

---

## 📱 Application Screenshots

<p align="center">
  <img src="screenshots/welcome-screen.png" width="220" alt="Welcome Screen"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="screenshots/avatar-chat.png" width="220" alt="AI Avatar Assistant"/>
</p>

<p align="center">
  <b>Welcome Experience</b> 
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <b>AI Outfit Assistant</b>
</p>

<p align="center">
  <img src="screenshots/outfit-recommendation.png" width="220" alt="Outfit Recommendation"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="screenshots/commute-layer.png" width="220" alt="Weather Aware Layering"/>
</p>

<p align="center">
  <b>Personalized Outfit Recommendation</b>
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  <b>Weather-Aware Layer Suggestions</b>
</p>

<br>

> [!NOTE]
> FitCast provides a personalized outfit recommendation experience powered by real-time weather data, machine learning predictions, user preferences, and context-aware clothing rules. The application includes an interactive avatar assistant, adaptive weather backgrounds, outfit visualization, and dynamic layering recommendations for daily commutes and activities.

---

## 🚀 Features

### 🧠 Intelligent Outfit Recommendations & Layers
* **Contextual Suggestions:** Generates complete outfit suggestions based on current weather conditions and specific activities.
* **Machine Learning Engine:** Uses a custom-trained **Random Forest model** via Scikit-Learn to estimate thermal clothing requirements and predict appropriate clothing layers.
* **Occasion Adaptation:** Supports casual, formal, university, office, gym, travel, and airport contexts.

### 🌦️ Advanced Weather Analysis
* **Live Ingestion:** Retrieves real-time weather data using the OpenWeather API.
* **Bioclimatic Metrics:** Evaluates Temperature, Humidity, Wind Speed, Rain Conditions, and UV Index to assess real environmental conditions.

### 🔄 Personalization & Adaptive Comfort
* **Feedback Loop:** Personalized recommendations improve continuously through active user feedback (*Too Cold*, *Comfortable*, *Too Warm*).
* **Preference Matching:** Supports different comfort preferences and baseline profiles stored using Firebase.

### 🕋 Modesty & Lifestyle Support
* **Modesty Logic Tiers:** Tailors item pools to user profiles—including dedicated logic variations for *Hijabi* and modest outfit configurations.
* **Health & Safety Injections:** Automatically recommends protective accessories for users with underlying sensitivities (e.g., asthma) when environmental conditions may be harmful.

### 💬 AI Assistant Interaction
* **Intent Extraction:** Integrates OpenAI APIs for intelligent, natural language interaction.
* **Conversational Input:** Dynamically processes unstructured user requests to parse target events and clothing options.

### 👤 Dynamic Avatar System
* **Visualization Stack:** Renders outfit combinations using a customizable, responsive avatar layer.
* **Adaptive Backgrounds:** Reflects current weather conditions visually inside the client UI.

---

## 🛠️ Technology Stack

| Category | Technology |
| :--- | :--- |
| **Frontend Mobile Client** | Flutter, Dart |
| **Backend API Service** | FastAPI, Python |
| **Machine Learning Core** | Scikit-Learn |
| **Database Architecture** | Cloud Firestore |
| **User Authentication** | Firebase Authentication |
| **External Integrations** | OpenWeather API, OpenAI API |
| **UI/UX Prototyping** | Figma |

---

## 🏗️ System Architecture

FitCast follows a modular full-stack architecture designed to decouple the presentation client from backend calculation heavy lifting:

1. **Flutter Mobile Application:** Handles presentation layer, UI views, and vector graphics rendering.
2. **FastAPI Backend Service:** Coordinates core feature engineering and hosts predictive endpoints.
3. **Machine Learning Prediction Engine:** Performs inference over environmental vectors.
4. **Firebase Infrastructure:** Secures credentials via Firebase Auth and provides structured storage via Firestore NoSQL collections.
5. **Third-Party APIs:** OpenWeather and OpenAI integrations handle live forecast data and text classification respectively.

---

## 📂 Future Improvements
* **Digital Wardrobe Management:** Edge-based object classification to allow users to scan and register their physical apparel closets.
* **Clothing Image Recognition:** Computer vision pipeline integrations for asset tagging and category indexing.
* **Proactive Calendar Integration:** Syncing with external calendars for automatic lookahead weather-outfit calculations.

---

## 🔒 Security Notice
> [!IMPORTANT]
> To comply with security best practices, production API keys, Firebase service account configuration tokens (`google-services.json`), environment variables, and serialized model binaries have been omitted from this repository.

---

## 👤 Author
* **Ayah Said** — Computer Science Student, German Jordanian University (GJU)
