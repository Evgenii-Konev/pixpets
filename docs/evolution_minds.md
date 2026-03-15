# PixPets — Product Evolution Plan

## Vision

PixPets — первый "personal agent observability" инструмент с эмоциональным якорем. Стратегия: захватить категорию через charm, удержать через данные и привычку, монетизировать через pro-features и marketplace.

Core positioning: **"Pixel pets for AI coding agents"** — не разбавлять "enterprise observability".

---

## Feature Roadmap

### Tier 1 — Core Value (Q2 2026)

#### 1.1 Session Analytics
- Время работы каждого агента, количество tool calls, статистика по проектам
- Расширить SessionFile: `tool_calls`, `session_start`, `tokens_in`, `tokens_out`
- Попувер с графиком за день
- Превращает PixPets из "мониторинга" в "аналитику производительности"

#### 1.2 Smart Notifications
- macOS native уведомления:
  - Агент завершил длинную задачу (working -> idle после >30с)
  - Агент ждёт ответа >2 мин (waiting)
  - Агент упал (PID исчез)
- Настраиваемые пороги через preferences pane

#### 1.3 Расширенная поддержка агентов
- Aider, Continue, Windsurf, Copilot CLI
- Generic hook installer и документация для интеграции
- Архитектура `AgentType.swift` уже extensible через enum

### Tier 2 — Differentiation (Q3 2026)

#### 2.1 Pet Evolution System
- Питомцы "прокачиваются" на основе реального использования
- 100 успешных tool calls = новая анимация
- 1000 = новый уровень/скин
- Gamification создаёт эмоциональную привязанность и switching costs
- `PixelCharacter.swift` с 18x18 гридами позволяет добавлять спрайты

#### 2.2 Session Timeline
- История всех сессий за день/неделю/месяц
- Хранение в SQLite (`~/.pixpets/history.db`)
- "Где я провёл время? Какой агент был эффективнее?"

#### 2.3 Quick Actions из попувера
- Отправить сообщение агенту (stdin pipe)
- Остановить агент (SIGINT)
- Открыть лог сессии
- Превращает PixPets из пассивного наблюдателя в control plane

#### 2.4 Multi-agent Orchestration View
- Визуализация взаимосвязей между агентами на одном проекте
- 3 агента на одном репо = "команда питомцев" с общим контекстом

### Tier 3 — Scale (Q4 2026 — Q1 2027)

#### 3.1 Team Features
- Shared dashboard (CloudKit или websocket сервер)
- "Кто из коллег сейчас кодит с агентом?"
- Агрегированная статистика для тимлидов

#### 3.2 iPhone / Apple Watch Companion
- Уведомления на часы когда агент ждёт
- SwiftUI виджет с текущим статусом
- Killer feature для тех, кто отходит от компьютера

#### 3.3 Marketplace
- Кастомные стили питомцев (коты, драконы, роботы)
- Темы попувера (dark, retro, neon)
- Simple JSON/Swift format для pixel art
- Сообщество создателей

#### 3.4 Cross-machine Sync
- iCloud для синхронизации настроек и истории
- Persisted preferences между Mac'ами

#### 3.5 Windows / Linux
- Tauri или отдельная реализация
- Удвоит базу пользователей, утроит сложность
- Сначала стать лидером на macOS, потом расширяться

---

## Monetization

### Pricing Model: Freemium + Marketplace

| Tier | Price | Features |
|------|-------|----------|
| **Free** | $0 | До 3 агентов, базовые нотификации, история 24ч, 1 стиль питомца |
| **Pro** | $8/мес, $69/год, $149 lifetime | Безлимит агентов, полная аналитика, pet evolution, кастомные нотификации (Discord/Slack/Telegram), quick actions, Apple Watch, приоритетная поддержка |
| **Team** | $5/юзер/мес (мин. 5) | Всё из Pro + team dashboard, агрегированная статистика, admin console |
| **Marketplace** | 30% комиссия | Кастомные питомцы, темы, контент от сообщества |

---

## Go-to-Market

### Phase 1: Seed (месяц 1-2)
- **Product Hunt** — 30с GIF-видео, tagline: "Your AI coding agents deserve pixel pets"
- **Twitter/X thread** — визуальный контент с анимациями
- **r/programming, r/macapps, Hacker News** — Show HN с фокусом на "zero dependencies, pure Swift"

### Phase 2: Grow (месяц 2-4)
- Dev-блогеры (ThePrimeagen, Fireship) — питомцы как фон для стримов про AI coding
- Claude Code / Codex community Discord/Slack
- Homebrew в каждом README и tutorial

### Phase 3: Moat (месяц 4-8)
- Партнёрства с Anthropic, OpenAI, Cursor — включить в recommended tools
- Опубликовать спецификацию SessionFile как открытый стандарт
- Стать протоколом, а не просто приложением

---

## KPIs

| Quarter | Target |
|---------|--------|
| Q2 2026 | 1,000 установок, 100 DAU |
| Q3 2026 | 5,000 установок, 50 платящих |
| Q4 2026 | 15,000 установок, 200 платящих |
| Q1 2027 | 50,000 установок, 500 платящих |

**North Star Metric:** Weekly active users с 2+ мониторируемыми агентами.

---

## Competitive Moat

1. **Emotional moat** — привязанность к прокачанным питомцам (evolution, кастомизация)
2. **Data moat** — накопленная история сессий, персональная аналитика
3. **Network effects** — marketplace и team features
4. **Brand moat** — "pixel pets for AI agents" = категория = бренд
5. **Simplicity moat** — zero dependencies, pure Swift = антихрупкость

---

## Risks

| Risk | Probability | Mitigation |
|------|-------------|------------|
| Hook API changes | Medium | Push-модель через файловую систему — стабильный контракт |
| AI tool vendor клонирует | Low | Emotional moat + data moat + first-mover |
| macOS only ограничивает рост | Medium | 70%+ target audience на macOS; Windows/Linux в Tier 3 |
| Рынок схлопнется до 1-2 агентов | Low | Тренд на фрагментацию и специализацию |
| Apple встроит agent monitoring | Very Low | Не в формате pixel pets; наблюдать WWDC |

---

## Design Principles

1. Каждая функция должна быть **charming**, а не просто полезной
2. **Zero dependencies** — стратегическое преимущество, не ограничение
3. **Barbell strategy** — 90% на стабильный core, 10% на эксперименты
4. Не добавлять complexity без clear user value
5. Push-based architecture как основа (hooks → FSEvents → UI)
