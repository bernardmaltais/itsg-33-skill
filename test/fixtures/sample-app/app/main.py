"""
Sample Protected B application entry point.
SI-10 FAIL: user input passed to query without validation.
SI-11 PASS: generic error responses (no stack traces to client).
"""

import os
import sqlite3
from flask import Flask, request, jsonify

app = Flask(__name__)
DB_PATH = os.environ.get("DB_PATH", "/data/app.db")


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/items")
def get_items():
    # SI-10 FAIL: user input concatenated directly into SQL query
    category = request.args.get("category", "")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    query = "SELECT * FROM items WHERE category = '" + category + "'"  # SQL injection
    cursor.execute(query)
    rows = cursor.fetchall()
    conn.close()
    return jsonify(rows)


@app.route("/items/<item_id>")
def get_item(item_id):
    # SI-11 PASS: generic error — no internal details exposed
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        # SI-10 PASS: parameterized query on this endpoint
        cursor.execute("SELECT * FROM items WHERE id = ?", (item_id,))
        row = cursor.fetchone()
        conn.close()
        if row is None:
            return jsonify({"error": "not found"}), 404
        return jsonify(row)
    except Exception:
        return jsonify({"error": "internal server error"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
