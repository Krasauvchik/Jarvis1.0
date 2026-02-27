# Выложить проект на GitHub

Коммит уже сделан (ветка `jarvis-full`). Осталось создать репозиторий на GitHub и отправить код.

## 1. Создать репозиторий на GitHub

1. Зайдите на [github.com/new](https://github.com/new).
2. Укажите имя репозитория, например **Jarvis** или **jarvis-planner**.
3. **Не** добавляйте README, .gitignore и лицензию (они уже есть в проекте).
4. Нажмите **Create repository**.

## 2. Подключить remote и отправить код

В терминале выполните (подставьте свой логин и имя репозитория):

```bash
cd /Users/Bill/.cursor/worktrees/Cursor/ifq
git remote add origin https://github.com/ВАШ_ЛОГИН/ИМЯ_РЕПОЗИТОРИЯ.git
git push -u origin jarvis-full
```

Пример:
```bash
git remote add origin https://github.com/krasauvchik/Jarvis.git
git push -u origin jarvis-full
```

Если репозиторий уже был создан с README и вы получили ошибку при push, сделайте:

```bash
git pull origin main --allow-unrelated-histories
# или сначала: git fetch origin && git merge origin/main --allow-unrelated-histories
git push -u origin jarvis-full
```

## 3. Сделать jarvis-full основной веткой (по желанию)

На GitHub: **Settings** → **Branches** → Default branch → выбрать **jarvis-full** → Update.

Либо переименовать ветку в `main` и пушить:

```bash
git branch -m jarvis-full main
git push -u origin main
```

---

**Важно:** В репозиторий не попадают `credentials.json` и `token.json` (они в .gitignore). После клонирования нужно будет снова положить `credentials.json` в `jarvis-backend/` для работы Google OAuth.
