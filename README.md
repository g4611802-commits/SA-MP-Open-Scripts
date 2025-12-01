# 🚀 SA-MP Open Scripts
Coleção de scripts abertos para SA-MP (San Andreas Multiplayer) — incluindo sistemas, comandos, utilidades, filtroscripts e módulos de gameplay.  
Tudo escrito em **Pawn**, organizado, comentado e pronto para uso ou estudo.

---

## 📌 Sobre o Projeto
Este repositório reúne diversos scripts e sistemas criados para facilitar o desenvolvimento de servidores SA-MP, servindo como:

- Base de aprendizado para iniciantes  
- Referência para desenvolvedores intermediários  
- Biblioteca para quem quer adicionar recursos rapidamente ao servidor  

Todos os scripts são **open-source** e podem ser usados, modificados e redistribuídos livremente (seguindo a licença escolhida).

---

## 🧩 Conteúdo
✔️ Sistemas completos (UX com dialogs, salvamento, timers, validações)  
✔️ Comandos úteis para administração e gameplay  
✔️ Algoritmos otimizados em Pawn  
✔️ Filtroscripts plug-and-play  
✔️ Integrações com plugins (streamer, sscanf, MySQL etc.)  
✔️ Exemplos práticos com comentários explicativos  

---

## 📂 Estrutura do Repositório

/src/ → Códigos-fonte .pwn
/include/ → Includes personalizados
/filterscripts/ → Scripts independentes
/gamemodes/ → Gamemodes completos
/docs/ → Documentação adicional
/build/ → Versões compiladas (.amx)

yaml
Copiar código

---

## 🔧 Requisitos

- **SA-MP Server 0.3.7 / open.mp**  
- **Pawn Compiler** (3.10 ou superior)  
- Plugins recomendados:  
  - `sscanf`  
  - `streamer`  
  - `mysql` (se houver sistemas com DB)  

---

## ▶️ Como Usar

1. Baixe ou clone o repositório:
   ```bash
   git clone https://github.com/SEU_USUARIO/samp-open-scripts
Edite ou compile os scripts:

bash
Copiar código
pawncc src/seu_script.pwn
Mova o .amx para:

bash
Copiar código
/gamemodes/  ou  /filterscripts/
Adicione no server.cfg:

nginx
Copiar código
gamemode0 seu_script
filterscripts seu_filtroscript
Inicie o servidor e divirta-se! 😎

📚 Documentação
Cada script possui comentários internos explicando o funcionamento.
A pasta /docs também pode conter manuais e tutoriais extras.

Se quiser, posso gerar documentação automática estilo wiki.

🤝 Contribuindo
Contribuições são bem-vindas!

Faça um fork

Crie um branch de feature

Envie um pull request

Aguarde aprovação 🎉

📝 Licença
Este projeto está sob a licença MIT — permitindo uso livre, inclusive comercial.
(Se quiser, posso trocar para GPL, CC, Apache, BSD ou outra.)

⭐ Apoie o Projeto
Se este repositório te ajudou:

Dê uma estrela ⭐ no Github

Compartilhe com outros devs SA-MP

📬 Contato
Se quiser ajuda, scripts exclusivos ou otimizações, basta abrir uma Issue ou me chamar!
