import os
import json
from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, auth
import psycopg2
from dotenv import load_dotenv
import string
import random

# Load environment variables
load_dotenv()


avalaibleChars =  list(string.ascii_uppercase) + list(string.ascii_lowercase) + ['0','1','2','3','4','5','6','7','8','9']

# Initialize Firebase Admin SDK
cred = credentials.Certificate("firebase_admin.json")
firebase_admin.initialize_app(cred)

# Initialize DB connection
conn = psycopg2.connect(
    dbname=os.environ["DB_NAME"],
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASS"],
    host=os.environ["DB_HOST"]
)
cur = conn.cursor()

# Initialize Flask
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})  # Enable CORS for all origins, adjust for production

@app.route("/users", methods=["POST"])
def add_user():
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return jsonify({"error": "Missing token"}), 401
    id_token = auth_header.split(" ")[1]

    try:
        decoded_token = auth.verify_id_token(id_token)
        uid = decoded_token["uid"]
        email = decoded_token.get("email", "")
    except Exception as e:
        return jsonify({"error": "Invalid token", "details": str(e)}), 401

    data = request.get_json()
    username = data.get("username", "").strip()
    if not username:
        return jsonify({"error": "Username required"}), 400


    cur.execute("SELECT COUNT(*) FROM users WHERE firebase_uid = %s", (uid,))
    if cur.fetchone()[0] > 0:
        return jsonify({"error": "This user already has a username"}), 400

    cur.execute("SELECT COUNT(*) FROM users WHERE username = %s", (username,))
    if cur.fetchone()[0] > 0:
        return jsonify({"error": "Username already taken"}), 400
    cur.execute(
        "INSERT INTO users (firebase_uid, email, username) VALUES (%s, %s, %s)",
        (uid, email, username)
    )
    conn.commit()

    return jsonify({"status": "success", "uid": uid, "username": username}), 200


@app.route("/getusername", methods=["POST"])
def get_username():
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return jsonify({"error": "Missing token"}), 401
    id_token = auth_header.split(" ")[1]

    try:
        decoded_id = auth.verify_id_token(id_token)
        uid = decoded_id["uid"]
    except Exception as e:
        return jsonify({"error": "Invalid token", "details": str(e)}), 401

    cur.execute("SELECT username FROM users where firebase_uid = %s", (uid,))

    try:
        return jsonify({"status": "success", "username": cur.fetchone()[0]}), 200
    except:
        return jsonify({"status": "failure"}), 401

@app.route("/createchat", methods=["POST"])
def create_chat():
    raise NotImplementedError #Not done coding this
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return jsonify({"error": "Missing token"}), 401
    id_token = auth_header.split(" ")[1]

    data = request.get_json()

    users = data.get("users ").split(",") #get users that the request wants to add to the chat

    while True:
        chatID = [random.choice(avalaibleChars) for _ in range(255)] #62 char options by 256 => 62**256 options should be plenty
        cur.execute("SELECT COUNT(*) FROM chatrooms WHERE chat_id = %s", (chatID,))#
        if cur.fetchone()[0] > 0:
            break#chose a new ID until there is not already a chat that it exists in


    cur.execute("INSERT INTO chatrooms (chat_id) VALUES (%s)",(chatID,))#create table entry with nothing inside of it
    cur.execute("")

    db_users = []

    for user in users:
        pass #add user to DB need to parse into postgress list (single quotes and whatnot)

    cur.execute("INSERT INTO chatrooms (users) VALUES (ARRAY[%s])",(db_users,))#This must be modified

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
