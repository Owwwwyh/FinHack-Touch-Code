"""
Convert XGBoost model to TF Lite for on-device inference.
Per docs/04-credit-score-ml.md §5 (distillation to TF Lite).
Uses Treelite as intermediary: XGBoost → Treelite → TFLite.

Usage:
  python convert_tflite.py --model-dir ./model_output --output ./model_output/model.tflite
"""

import argparse
import os
import json
import numpy as np


def convert_with_treelite(model_path: str, output_path: str):
    """Convert XGBoost model to TF Lite via Treelite."""
    try:
        import treelite
        import treelite_runtime
        import tensorflow as tf
        import pickle

        # Load the XGBoost model
        with open(model_path, "rb") as f:
            artifact = pickle.load(f)

        xgb_model = artifact["model"]
        feature_cols = artifact["feature_cols"]

        # Export XGBoost model to a format Treelite can read
        xgb_model_path = model_path.replace(".pkl", ".xgb")
        xgb_model.save_model(xgb_model_path)

        # Convert via Treelite
        model = treelite.Model.load(xgb_model_path, model_format="xgboost")

        # Compile to shared library
        toolchain = "gcc"
        lib_path = output_path.replace(".tflite", ".so")
        model.export_lib(
            toolchain=toolchain,
            libpath=lib_path,
            params={"parallel_comp": 4},
        )

        # Now create a TF Lite surrogate model
        # For simplicity, we create a small neural network that mimics the tree
        n_features = len(feature_cols)

        # Build a surrogate model
        model_tf = tf.keras.Sequential([
            tf.keras.layers.Input(shape=(n_features,)),
            tf.keras.layers.Dense(64, activation='relu'),
            tf.keras.layers.Dense(32, activation='relu'),
            tf.keras.layers.Dense(1),
        ])

        # Generate training data from the XGBoost model predictions
        n_samples = 50000
        X_synth = np.random.randn(n_samples, n_features).astype(np.float32)
        # Clip features to reasonable ranges
        X_synth = np.clip(X_synth, -5, 50)
        y_synth = xgb_model.predict(X_synth).astype(np.float32)

        model_tf.compile(optimizer='adam', loss='mse', metrics=['mae'])
        model_tf.fit(X_synth, y_synth, epochs=20, batch_size=256, verbose=1, validation_split=0.1)

        # Convert to TF Lite
        converter = tf.lite.TFLiteConverter.from_keras_model(model_tf)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float32]
        tflite_model = converter.convert()

        with open(output_path, "wb") as f:
            f.write(tflite_model)

        print(f"TF Lite model saved to {output_path}")
        print(f"Model size: {os.path.getsize(output_path) / 1024:.1f} KB")

    except ImportError as e:
        print(f"Warning: {e}. Falling back to simple TF Lite model.")
        create_simple_tflite(output_path, len(artifact.get("feature_cols", [])))


def create_simple_tflite(output_path: str, n_features: int = 20):
    """Create a simple placeholder TF Lite model when full conversion isn't available."""
    try:
        import tensorflow as tf

        model = tf.keras.Sequential([
            tf.keras.layers.Input(shape=(n_features,)),
            tf.keras.layers.Dense(32, activation='relu'),
            tf.keras.layers.Dense(16, activation='relu'),
            tf.keras.layers.Dense(1),
        ])
        model.compile(optimizer='adam', loss='mse')

        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()

        with open(output_path, "wb") as f:
            f.write(tflite_model)

        print(f"Simple TF Lite model saved to {output_path}")
        print(f"Model size: {os.path.getsize(output_path) / 1024:.1f} KB")

    except ImportError:
        print("TensorFlow not available. Skipping TF Lite conversion.")
        print("Install with: pip install tensorflow")


def main():
    parser = argparse.ArgumentParser(description="Convert XGBoost to TF Lite")
    parser.add_argument("--model-dir", type=str, default="./model_output", help="Model directory")
    parser.add_argument("--output", type=str, default=None, help="Output TFLite path")
    args = parser.parse_args()

    model_path = os.path.join(args.model_dir, "model.pkl")
    output_path = args.output or os.path.join(args.model_dir, "model.tflite")

    if not os.path.exists(model_path):
        print(f"Model not found at {model_path}. Creating simple placeholder.")
        create_simple_tflite(output_path)
    else:
        convert_with_treelite(model_path, output_path)

    # Save manifest
    manifest = {
        "format": "tflite",
        "version": 1,
        "features": 20,
        "output": "safe_offline_balance_myr",
        "created_at": str(np.datetime64("now")),
    }
    manifest_path = output_path.replace(".tflite", ".json")
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"Manifest saved to {manifest_path}")


if __name__ == "__main__":
    main()
