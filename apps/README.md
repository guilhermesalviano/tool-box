# 🖱️ Apps do Tool-Box

Documentação dos aplicativos gráficos em `apps/`. Rodam pelo CLI mestre a
partir da raiz do repositório: `./toolbox <nome-do-app> [ação/argumentos]`.

---

## 🖱️ App: `swain-macros`

App GNOME (Ubuntu, Wayland e X11) que troca a função dos botões laterais do
mouse Redragon Swain por macros (teclas, texto, cliques, scroll, comandos).
Usa o `python3` do sistema, não o `.venv`.

```bash
# Configuração inicial (uma vez; pede sudo quando precisa):
./toolbox swain-macros install

# Abrir o app (ou pelo menu de aplicativos):
./toolbox swain-macros
```

Veja [`swain-macros/README.md`](swain-macros/README.md) para a linguagem de macros e como desinstalar.
