<p align="center">
  <img src="/public/images/ZealotAi_Round.png" height="120" alt="ZealotAI Logo"/>
</p>

<h1 align="center">ZealotAI</h1>
<h2 align="center">AeitherFlow Business Suite</h2>

<p align="center">
  Built with <a href="https://nextjs.org">Next.js</a> and <a href="https://flask.palletsprojects.com">Flask</a><br/>
  Designed to deliver intelligent, responsive, and modular business tools.
</p>

---

## 🧠 About ZealotAI

The **ZealotAI Business Suite** is a modular web-based platform designed to streamline small-to-medium business operations. It merges a **Next.js frontend** with a **Flask backend** to create a fast, modern, and Python-compatible development environment.

This platform is being built with mobile-first responsiveness in mind and is continuously evolving to integrate AI-powered features into practical business workflows.

---

## ✅ Current Features

- **🗓️ Diary** – Schedule and track your team's tasks.
- **🚚 Drivers & Logistics** – Manage deliveries, pickups, and driver scheduling.
- **📋 Task Management** – Integrated into the diary to assign and monitor responsibilities.

---

## 🛠️ Upcoming Modules

- **🤖 AI Chatbot Interface** – Context-aware AI assistant integrated into your workflow.
- **📇 CRM Module** – Customer relationship management with insights and automation.
- **💰 Debtors Module** – Track accounts receivable and overdue payments.
- **📦 Inventory Management** – Handle stock levels, lead times, and sales forecasting.

---

## ⚙️ Architecture Overview

This is a hybrid project with:

- **Frontend**: Built using [Next.js](https://nextjs.org) for high-performance SSR/CSR pages.
- **Backend**: Powered by [Flask](https://flask.palletsprojects.com) to support business logic and AI capabilities in Python.
- **Routing**: All `/api/*` requests from Next.js are rewritten and routed to the Flask server.

During development:
- Next.js runs on `http://localhost:3000`
- Flask runs on `http://127.0.0.1:5328`

The rewrite rules are managed via `next.config.js`.

---

## 🚀 Getting Started

Clone this repository and install dependencies:
