# example_api_source/main.py
from flask import Flask, jsonify
import os
import datetime

app = Flask(__name__)

@app.route('/api/status')
def api_status():
    return jsonify({
        "status": "API is running",
        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
        "message": "Hello from the deployed API!",
        "repository_name": os.getenv("GITHUB_REPOSITORY", "N/A")
    })

@app.route('/')
def home():
    return "API is alive! Visit /api/status for details."

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(debug=False, host="0.0.0.0", port=port)

