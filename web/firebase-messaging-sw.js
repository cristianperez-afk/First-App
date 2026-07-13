importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBjB71OAF2sMmpM5XRR9BiNtNhgiJ4NgYE",
  appId: "1:1019474035520:web:192e50744dfa3827fa30a5",
  messagingSenderId: "1019474035520",
  projectId: "child-immunization-tracker",
  authDomain: "child-immunization-tracker.firebaseapp.com",
  storageBucket: "child-immunization-tracker.firebasestorage.app"
});

const messaging = firebase.messaging();
