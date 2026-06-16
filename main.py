from fastapi import FastAPI
import joblib
import pandas as pd

app = FastAPI()

# 🔑 Load the trained ML model ONCE when the server starts
model = joblib.load("weather_model_v1.pkl")


@app.post("/predict-layer")
def predict_layer(data: dict):
    """
    Receives weather + user features from Flutter
    Returns predicted clothing layer (0–5)
    """

    # 1️⃣ Convert incoming JSON to DataFrame
    df = pd.DataFrame([data])

    # 2️⃣ One-hot encode rain_type (same as training)
    df = pd.get_dummies(df, columns=["rain_type"], prefix="rain")

    # 3️⃣ 🔑 CRITICAL: Force same feature schema as training
    df = df.reindex(
        columns=model.feature_names_in_,
        fill_value=0
    )

    # 4️⃣ Predict layer
    layer = int(model.predict(df)[0])

    return {"layer": layer}
