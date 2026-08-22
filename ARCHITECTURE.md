# Arquitetura Velociclos

## Repositórios (fontes de verdade)

| Repositório | Path | Tecnologia | Papel | CI |
|---|---|---|---|---|
| `Velociclos-backend` | `E:\Users\Public\Velociclos-backend` | Python 3.12 (stdlib) | Proxy/cache do YouTube + API legacy | GitHub Actions (`fa77151`+`3da9af4`) |
| `Velociclos-Fimathe` (frontend) | `E:\Users\Public\Velociclos-Fimathe\frontend` | Next.js 15 + React 19 + Supabase | App admin/membro (dashboard/cursos/artigos/leads/downloads/comunidade) | GitHub Actions (`7300732`) |
| `Velociclos-PCM` | `E:\Users\Public\Velociclos-PCM` | HTML/CSS/JS estático | Site público estático | — |

> A raiz `Velociclos-Fimathe` (contém `frontend/`, `backend/` snapshot antigo, HTML legado) **não é um repo** — evita duplicatas. Cada fonte vive no seu próprio repo.

## Fonte única de dados
**Supabase (schema `initial_schema`)**, em `frontend/supabase/migrations/20240101000000_initial_schema.sql`.
- Frontend lê/escreve diretamente via cliente Supabase (`@supabase/ssr`).
- Backend **não consome** o Supabase (é só proxy do YouTube) → não há silo JSON↔Supabase ativo.
- O schema CMS em `frontend/supabase/migrations/20260819_cms_schema.sql` e em `Velociclos-PCM/supabase-cms-legacy/` são **forks/órfãos** — NÃO aplicar no projeto canônico.

## Segurança (backend, `fa77151`)
- Escritas (`POST/PUT/DELETE /api/videos`, `/api/courses/sync`, `/admin/`) exigem `Authorization: Bearer <token>` validado via JWT do Supabase (HS256, `SUPABASE_JWT_SECRET`).
- Fail-closed: sem `SUPABASE_JWT_SECRET`, todas retornam 401.
- `ADMIN_PASSWORD` removido; `ThreadingHTTPServer` (concorrência).
- `do_POST` corrigido (parse de `path`).

## CI (ambos)
- Backend: `py_compile` + smoke test.
- Frontend: `npm ci` → `next lint` → `next build` (NEXT_PUBLIC_* via secrets).

## To-Do de ativação (requer conta do operador)
1. Criar remote GitHub para `frontend`, configurar secrets (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_BACKEND_URL`), push → CI ativo.
2. No backend (já tem remote `github.com/Igorsiqueirafx/Velociclos`): push das 2 commits; secrets no Railway: `YOUTUBE_API_KEY` e `SUPABASE_JWT_SECRET`.
3. Aplicar migrations no Supabase real: `supabase link` + `supabase db push` (ou SQL no dashboard).
