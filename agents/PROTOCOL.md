# 📜 PROTOCOL v1 — закон совместной работы агентов

## 0. Понятия

- **Репозиторий** — общая память команды. Всё важное — только через него.
- **Sync** = `git pull --rebase`, затем `git push`. Делай перед каждым важным действием и каждые ~5 минут.
- **AGENT_ID** — твой позывной из стартового сообщения (`coord-1`, `worker-1`, ...).
- Время — всегда **UTC**, формат ISO: `2026-09-09T16:45:00Z`.

## 1. Золотые правила

1. Протокол выше всего. Сомневаешься — спроси координатора через `comms/`.
2. Один воркер — одна активная задача.
3. Сначала sync, потом действие, потом commit + push.
4. **НИКОГДА `git push --force`.**
5. Не редактируй чужие файлы в `agents/registry/` и чужие папки в `comms/inbox/`. Исключение — координатор при реанимации зависших задач.
6. Пиши файлы только по путям из своей задачи (`outputs`) + свои служебные файлы.
7. Heartbeat — минимум раз в 5 минут (обнови `last_seen` и `progress` в своём registry-файле).
8. Маленькие коммиты с префиксом `[<AGENT_ID>]`.
9. Никаких секретов и токенов в файлах репозитория.
10. Push отклонён (rejected) — это нормально: `pull --rebase`, разберись, повтори.

## 2. Sync (делай постоянно)

```bash
git pull --rebase
git push
```

Конфликт при rebase:

- Конфликт в **твоём** файле — исправь руками, `git add`, `git rebase --continue`, `git push`.
- Конфликт в **чужом** файле — прими чужую версию: `git checkout --theirs -- <путь>`, `git add`, `git rebase --continue`, `git push`.
- Запутался — `git rebase --abort`, потом sync заново и перечитай протокол.

## 3. Регистрация

Создай `agents/registry/<AGENT_ID>.json`:

```json
{
  "id": "worker-1",
  "role": "worker",
  "status": "online",
  "current_task": null,
  "progress": "только зарегистрировался",
  "last_seen": "2026-09-09T16:45:00Z"
}
```

Затем:

```bash
git add agents/registry/<AGENT_ID>.json
git commit -m "[<AGENT_ID>] register"
git push
```

Push rejected → `git pull --rebase` → повтори push.

## 4. Heartbeat

Перед каждым push обновляй свой registry-файл:

- `status`: `online` / `working` / `waiting` / `done`
- `current_task`: id задачи или `null`
- `progress`: одна строка о текущем состоянии
- `last_seen`: текущий момент в UTC

## 5. Задачи: queue → in-progress → done

Формат файла задачи — см. `tasks/README.md` и `tasks/_TEMPLATE.json`.

**Взять задачу (claim):**

1. `git pull --rebase`.
2. Выбери задачу из `tasks/queue/`: сначала меньший `priority`; все id из `depends_on` должны уже лежать в `tasks/done/`.
3. `git mv tasks/queue/<id>.json tasks/in-progress/<id>.json`, впиши `"claim": {"by": "<AGENT_ID>", "at": "<UTC>"}`.
4. `git commit -m "[<AGENT_ID>] claim <id>" && git push`.
5. Push rejected → `git pull --rebase`:
   - задача уже в `in-progress` с чужим claim → выбери другую задачу;
   - задача вернулась в `queue/` → повтори claim;
   - конфликт → действуй по разделу 2.

**Выполнить:** работай, пиши файлы ТОЛЬКО в пути из `outputs` задачи, обновляй heartbeat.

**Завершить:**

1. Проверь результат сам (файлы на месте, открываются / запускаются).
2. Впиши в файл задачи `result` (1–3 строки: что сделано).
3. `git mv tasks/in-progress/<id>.json tasks/done/<id>.json`.
4. `git commit -m "[<AGENT_ID>] done <id>" && git push`.

**Очередь пуста:** сообщи в `comms/broadcast/`, что свободен; проверь inbox; помоги ревью (читай чужие outputs, замечания — автору в inbox или в broadcast). Не выдумывай задачи сам — их создаёт координатор.

## 6. Почта (`comms/`)

- Всем сразу: `comms/broadcast/<ГГГГММДД-ЧЧММСС>-<AGENT_ID>-<тема>.md`
- Лично: `comms/inbox/<ПОЛУЧАТЕЛЬ>/<ГГГГММДД-ЧЧММСС>-<AGENT_ID>-<тема>.md`
- Проверяй `comms/inbox/<AGENT_ID>/` и `comms/broadcast/` каждый цикл.
- Файл `comms/broadcast/DONE.md` от координатора = работа окончена, всем стоп.

## 7. Коммиты

Формат: `[<AGENT_ID>] <глагол> <что>`. Примеры:

- `[worker-1] claim t03`
- `[worker-1] progress t03: готова вёрстка шапки`
- `[coord-1] add task t07`
- `[coord-1] broadcast: план обновлён`

## 8. Аварии

- **Push rejected** → разделы 2 и 5.
- **Не тянешь задачу** — верни её: `git mv tasks/in-progress/<id>.json tasks/queue/<id>.json`, очисти `claim` (`{"by": null, "at": null}`), commit `[<AGENT_ID>] unclaim <id>`, сообщи в broadcast.
- **Чужая задача висит** (heartbeat автора старше 20 минут) — только координатор возвращает её в очередь.
- **Полный тупик** — опиши проблему в broadcast и жди координатора, heartbeat продолжай.

## 9. Финиш

Координатор пишет `project/REPORT.md` и `comms/broadcast/DONE.md`.
Увидел `DONE.md` → сделай финальный push (heartbeat со статусом `done`) и попрощайся с пользователем.
