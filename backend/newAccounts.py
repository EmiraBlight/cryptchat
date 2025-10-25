import os
import json
from flask import Flask, request, jsonify
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, auth
import psycopg2
from dotenv import load_dotenv
import random
import string

# Load environment variables
load_dotenv()

CHATROOM_SIZES = 10

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
print("Connected!")
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
            auth_header = request.headers.get("Authorization", "")
            if not auth_header.startswith("Bearer "):
                return jsonify({"error": "Missing token"}), 401
            id_token = auth_header.split(" ")[1]

            data = request.get_json()
            try:
                decoded_token = auth.verify_id_token(id_token)
                uid = decoded_token["uid"]
            except Exception as e:
               return jsonify({"error": "Invalid token", "details": str(e)}), 401

            users = data.get("users ") #get users that the request wants to add to the chat AS USERNAMES
            db_users = [uid] #uids of users, starting with one building the chatroom
            for user in users:
                cur.execute("SELECT firebase_uid FROM users where username = %s", (user,))
                result = cur.fetchone()
                print(f"Finding user {user}")
                if result:
                        db_users.append(result)#if a user exists and has a username, add to db users

            print(f'Users before random: {db_users}')

            while True:
                chatID = [random.choice(avalaibleChars) for _ in range(255)] #62 char options by 256 => 62**256 options should be plenty
                chatID = "".join(chatID)
                cur.execute("SELECT COUNT(*) FROM chatrooms WHERE chat_id = %s", (chatID,))#
                result = cur.fetchone()[0]
                print(result)
                if result  ==  0:
                    break#chose a new ID until there is not already a chat that it exists in
                else:
                   # print(f"id: {chatID} failed!")
                   pass

            moreUsersToAdd = CHATROOM_SIZES - len(db_users)

            if moreUsersToAdd<0:
                return jsonify({"error": "too many users!"})

            cur.execute("SELECT firebase_uid FROM users ORDER BY random() LIMIT %s", (moreUsersToAdd,))
            sleeper_users = cur.fetchall() #returns a list of tuples from search. Each tuple should havde 1 entry as a uid

            new_users = [i[0] for i in sleeper_users] #get uid from results
            db_users+= new_users # add in sleeper users into the db

            print(f'Users after random: {db_users}')

            cur.execute("INSERT INTO chatrooms (chat_id, char_users) VALUES (%s,%s)",(chatID,db_users,))
            conn.commit()
            #TODO : add way to send invites to legit users so they have the chat ID as well
    return jsonify({"success": "all users added", "chat adress": chatID }), 200


if __name__ == "__main__":
    # For development
    app.run(host="0.0.0.0", port=5000, debug=True)
