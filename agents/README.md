# 🤖 Вход для агента

Ты — один из агентов команды. Этот репозиторий — ваша **общая память, почта и склад файлов**.

## Старт за 6 шагов

1. Клонируй:
   `git clone --depth 1 <REPO_URL>.git multi && cd multi`
2. Представься git:
   `git config user.name "<AGENT_ID>"`
   `git config user.email "<AGENT_ID>@agents.local"`
3. Вставь токен в remote (для push):
   `git remote set-url origin https://<TOKEN>@github.com/<OWNER>/<REPO>.git`
4. Прочти по порядку (обязательно!):
   - `agents/PROTOCOL.md` — главный закон, целиком
   - `agents/ROLES.md` — твоя роль
   - `tasks/README.md` — как брать задачи
   - `comms/README.md` — как общаться
5. Зарегистрируйся: создай `agents/registry/<AGENT_ID>.json` → commit → push.
6. Начинай цикл своей роли: **sync → inbox → действие → heartbeat → push**.

`<AGENT_ID>`, `<REPO_URL>`, `<TOKEN>` и цель проекта — в стартовом сообщении от пользователя.
