// ifood_phone.pwn
// SA-MP Pawn phone system: WhatsApp-like messages + Calls between players
// Usage (commands):
//  /phone           - mostra ajuda rápida
//  /mynumber        - mostra seu número
//  /addcontact <num> <nome> - adiciona contato (nome com _ para espaços)
//  /contacts        - lista contatos
//  /msg <num> <mensagem> - envia mensagem estilo WhatsApp
//  /inbox           - vê últimas mensagens recebidas (local)
//  /call <num>      - liga para um número
//  /accept          - aceita uma chamada que está tocando pra você
//  /decline         - recusa a chamada
//  /hangup          - encerra chamada ativa
//  /callmsg <texto> - mensagem enquanto em chamada (privado pro parceiro)

// Ajustes rápidos:
#define MAX_CONTACTS 64
#define MAX_MSGS 32         // mensagens salvas por jogador (inbox ring buffer)
#define MSG_LEN 128
#define RING_TIMEOUT_MS 20000 // 20 segundos para tocar

new PlayerNumber[MAX_PLAYERS];       // número do jogador (int)
new ContactCount[MAX_PLAYERS];
new ContactNumber[MAX_PLAYERS][MAX_CONTACTS];
new ContactName[MAX_PLAYERS][MAX_CONTACTS][32];

new MsgCount[MAX_PLAYERS];
new MsgFrom[MAX_PLAYERS][MAX_MSGS];
new MsgText[MAX_PLAYERS][MAX_MSGS][MSG_LEN];
new MsgIndex[MAX_PLAYERS]; // índice circular

// Calls
// CallState: 0 idle, 1 ringing (incoming), 2 in_call
new CallState[MAX_PLAYERS];
new CallPartner[MAX_PLAYERS]; // partner playerid when ringing/in_call
new CallTimerId[MAX_PLAYERS]; // timer handle id used (store as int returned by SetTimerEx if needed)

// Helpers forward
forward FindPlayerByNumber(number);
forward SendPlayerMessageTo(playerid, color, const[]);

public OnGameModeInit() {
    // nothing special for init
    return 1;
}

public OnPlayerConnect(playerid) {
    // assign unique phone number: base 1000 + playerid (você pode usar outro algoritmo)
    PlayerNumber[playerid] = 1000 + playerid;
    ContactCount[playerid] = 0;
    MsgCount[playerid] = 0;
    MsgIndex[playerid] = 0;
    CallState[playerid] = 0;
    CallPartner[playerid] = -1;

    new string[128];
    format(string, sizeof(string), "Bem-vindo! Seu número: %d  Use /phone para ver comandos.", PlayerNumber[playerid]);
    SendClientMessage(playerid, 0x00FF00FF, string);

    return 1;
}

public OnPlayerDisconnect(playerid, reason) {
    // cleanup: se em chamada, encerra para o outro
    if (CallState[playerid] == 2) {
        new partner = CallPartner[playerid];
        if (IsPlayerConnected(partner) && CallPartner[partner] == playerid) {
            SendClientMessage(partner, 0xFF0000FF, "A outra parte desconectou. Chamada encerrada.");
            CallState[partner] = 0;
            CallPartner[partner] = -1;
        }
    }
    // se estava tocando, cancela o toque
    if (CallState[playerid] == 1 && CallPartner[playerid] != -1) {
        new caller = CallPartner[playerid];
        if (IsPlayerConnected(caller)) {
            SendClientMessage(caller, 0xFF0000FF, "Chamada não atendida (jogador desconectou).");
            CallState[caller] = 0;
            CallPartner[caller] = -1;
        }
    }
    CallState[playerid] = 0;
    CallPartner[playerid] = -1;

    return 1;
}

// ------------------ COMMANDS ------------------

CMD:phone(playerid, params[]) {
    SendClientMessage(playerid, 0xFFFFFFFF, "---- CELULAR ----");
    SendClientMessage(playerid, 0xFFFFFFFF, "/mynumber - Mostrar seu número");
    SendClientMessage(playerid, 0xFFFFFFFF, "/addcontact <num> <nome> - Adicionar contato");
    SendClientMessage(playerid, 0xFFFFFFFF, "/contacts - Listar contatos");
    SendClientMessage(playerid, 0xFFFFFFFF, "/msg <num> <texto> - Enviar mensagem (WhatsApp)");
    SendClientMessage(playerid, 0xFFFFFFFF, "/inbox - Ver últimas mensagens");
    SendClientMessage(playerid, 0xFFFFFFFF, "/call <num> - Ligar");
    SendClientMessage(playerid, 0xFFFFFFFF, "/accept - Aceitar ligação");
    SendClientMessage(playerid, 0xFFFFFFFF, "/decline - Recusar ligação");
    SendClientMessage(playerid, 0xFFFFFFFF, "/hangup - Encerrar ligação");
    SendClientMessage(playerid, 0xFFFFFFFF, "/callmsg <texto> - Mensagem privada durante chamada");
    return 1;
}

CMD:mynumber(playerid, params[]) {
    new string[64];
    format(string, sizeof(string), "Seu número é: %d", PlayerNumber[playerid]);
    SendClientMessage(playerid, 0x00FFFF00, string);
    return 1;
}

CMD:addcontact(playerid, params[]) {
    new num;
    new name[32];
    if (!sscanf(params, "ui[32]", num, name)) {
        SendClientMessage(playerid, 0xFF0000FF, "Uso: /addcontact <numero> <nome>");
        return 1;
    }
    if (ContactCount[playerid] >= MAX_CONTACTS) {
        SendClientMessage(playerid, 0xFF0000FF, "Agenda cheia.");
        return 1;
    }
    ContactNumber[playerid][ContactCount[playerid]] = num;
    strcopy(ContactName[playerid][ContactCount[playerid]], sizeof(ContactName[][]), name);
    ContactCount[playerid]++;
    SendClientMessage(playerid, 0x00FF00FF, "Contato adicionado.");
    return 1;
}

CMD:contacts(playerid, params[]) {
    if (ContactCount[playerid] == 0) {
        SendClientMessage(playerid, 0xFFFFFFFF, "Agenda vazia. Use /addcontact.");
        return 1;
    }
    SendClientMessage(playerid, 0xFFFFFFFF, "---- Seus Contatos ----");
    new i;
    new buf[128];
    for (i=0; i<ContactCount[playerid]; i++) {
        format(buf, sizeof(buf), "%d - %s", ContactNumber[playerid][i], ContactName[playerid][i]);
        SendClientMessage(playerid, 0xFFFFFFAA, buf);
    }
    return 1;
}

CMD:msg(playerid, params[]) {
    new num;
    new text[128];
    if (!sscanf(params, "i[128]", num, text)) {
        SendClientMessage(playerid, 0xFF0000FF, "Uso: /msg <numero> <texto>");
        return 1;
    }
    new target = FindPlayerByNumber(num);
    new senderNumber = PlayerNumber[playerid];

    if (target == -1) {
        // destinatário offline -> armazenar na caixa (inbox) do número DESTINATÁRIO
        // como não temos mapeamento persistente, vamos procurar por PlayerNumber equal mesmo entre offline não existe.
        // Simples fallback: dizer que jogador está offline e salvar na sua caixa local do remetente como 'enviado'
        SendClientMessage(playerid, 0xFFFF00FF, "Jogador offline. Mensagem não entregue, armazenada localmente.");
        // Armazenar na caixa do remetente
        new idx = MsgIndex[playerid] % MAX_MSGS;
        sscanf(text, "%s", text); // garantir string
        MsgFrom[playerid][idx] = num; // salvamos número destinatário como 'from' para histórico local
        strcopy(MsgText[playerid][idx], sizeof(MsgText[][]), text);
        MsgIndex[playerid] = (MsgIndex[playerid] + 1) % MAX_MSGS;
        MsgCount[playerid] = min(MsgCount[playerid]+1, MAX_MSGS);
        return 1;
    }

    // entregar diretamente
    new buf[256];
    format(buf, sizeof(buf), "[WhatsApp] %d diz: %s", senderNumber, text);
    SendClientMessage(target, 0x00FF00FF, buf);
    SendClientMessage(playerid, 0x00FF00FF, "Mensagem enviada.");

    // armazenar no inbox do destinatário
    new idx2 = MsgIndex[target] % MAX_MSGS;
    MsgFrom[target][idx2] = senderNumber;
    strcopy(MsgText[target][idx2], sizeof(MsgText[][]), text);
    MsgIndex[target] = (MsgIndex[target] + 1) % MAX_MSGS;
    MsgCount[target] = min(MsgCount[target]+1, MAX_MSGS);

    return 1;
}

CMD:inbox(playerid, params[]) {
    if (MsgCount[playerid] == 0) {
        SendClientMessage(playerid, 0xFFFFFFFF, "Caixa vazia.");
        return 1;
    }
    SendClientMessage(playerid, 0xFFFFFFFF, "---- Últimas mensagens ----");
    new i;
    new start = (MsgIndex[playerid] + MAX_MSGS - MsgCount[playerid]) % MAX_MSGS;
    new buf[256];
    for (i=0; i<MsgCount[playerid]; i++) {
        new idx = (start + i) % MAX_MSGS;
        format(buf, sizeof(buf), "De %d: %s", MsgFrom[playerid][idx], MsgText[playerid][idx]);
        SendClientMessage(playerid, 0xFFFFFFAA, buf);
    }
    return 1;
}

// ----------------- CALLS -----------------

CMD:call(playerid, params[]) {
    new num;
    if (!sscanf(params, "i", num)) {
        SendClientMessage(playerid, 0xFF0000FF, "Uso: /call <numero>");
        return 1;
    }
    new callee = FindPlayerByNumber(num);
    if (callee == -1) {
        SendClientMessage(playerid, 0xFF0000FF, "Número não encontrado / jogador offline.");
        return 1;
    }
    if (callee == playerid) {
        SendClientMessage(playerid, 0xFF0000FF, "Você não pode ligar para você mesmo.");
        return 1;
    }
    if (CallState[playerid] != 0) {
        SendClientMessage(playerid, 0xFF0000FF, "Você já está em uma chamada ou tocando.");
        return 1;
    }
    if (CallState[callee] != 0) {
        SendClientMessage(playerid, 0xFF0000FF, "O número está ocupado.");
        return 1;
    }

    // iniciar toque
    CallState[playerid] = 1; CallPartner[playerid] = callee;
    CallState[callee] = 1; CallPartner[callee] = playerid;

    new bufCaller[128];
    new bufCallee[128];
    format(bufCaller, sizeof(bufCaller), "Ligando para %d...", num);
    format(bufCallee, sizeof(bufCallee), "Chamando... Você tem uma chamada de %d. Use /accept ou /decline.", PlayerNumber[playerid]);

    SendClientMessage(playerid, 0x00FFFF00, bufCaller);
    SendClientMessage(callee, 0x00FFFF00, bufCallee);

    // timer para timeout do toque (usamos SetTimerEx - chama CallRingTimeout)
    // passamos args: caller, callee
    SetTimerEx("CallRingTimeout", RING_TIMEOUT_MS, false, "ii", playerid, callee);

    return 1;
}

// callback do timeout do toque
public CallRingTimeout(callerid, calleeid) {
    // se ainda estiver tocando e par armazenado, cancela
    if (!IsPlayerConnected(callerid) || !IsPlayerConnected(calleeid)) {
        // cleanup se desconectou
        if (IsPlayerConnected(callerid)) { CallState[callerid] = 0; CallPartner[callerid] = -1; }
        if (IsPlayerConnected(calleeid)) { CallState[calleeid] = 0; CallPartner[calleeid] = -1; }
        return 1;
    }
    if (CallState[callerid] == 1 && CallPartner[callerid] == calleeid && CallState[calleeid] == 1 && CallPartner[calleeid] == callerid) {
        SendClientMessage(callerid, 0xFF0000FF, "Chamada não atendida (timeout).");
        SendClientMessage(calleeid, 0xFF0000FF, "Chamada perdida (timeout).");
        CallState[callerid] = 0; CallPartner[callerid] = -1;
        CallState[calleeid] = 0; CallPartner[calleeid] = -1;
    }
    return 1;
}

CMD:accept(playerid, params[]) {
    if (CallState[playerid] != 1 || CallPartner[playerid] == -1) {
        SendClientMessage(playerid, 0xFF0000FF, "Sem chamadas para aceitar.");
        return 1;
    }
    new caller = CallPartner[playerid];
    if (!IsPlayerConnected(caller)) {
        SendClientMessage(playerid, 0xFF0000FF, "O chamador desconectou.");
        CallState[playerid] = 0; CallPartner[playerid] = -1;
        return 1;
    }
    // estabelecer chamada
    CallState[playerid] = 2;
    CallState[caller] = 2;
    CallPartner[playerid] = caller;
    CallPartner[caller] = playerid;

    SendClientMessage(playerid, 0x00FF00FF, "Você atendeu a chamada.");
    SendClientMessage(caller, 0x00FF00FF, "Ligação atendida.");

    // opcional: desabilitar chat global para participantes (não implementado aqui)
    // você pode implementar 'canal de voz' criando filtros no OnPlayerText ou usando ShowPlayerDialog para UI.

    return 1;
}

CMD:decline(playerid, params[]) {
    if (CallState[playerid] != 1 || CallPartner[playerid] == -1) {
        SendClientMessage(playerid, 0xFF0000FF, "Sem chamadas para recusar.");
        return 1;
    }
    new caller = CallPartner[playerid];
    if (IsPlayerConnected(caller)) {
        SendClientMessage(caller, 0xFF0000FF, "Chamada recusada.");
    }
    SendClientMessage(playerid, 0xFF0000FF, "Você recusou a chamada.");

    CallState[playerid] = 0; CallPartner[playerid] = -1;
    if (IsPlayerConnected(caller)) { CallState[caller] = 0; CallPartner[caller] = -1; }

    return 1;
}

CMD:hangup(playerid, params[]) {
    if (CallState[playerid] == 0) {
        SendClientMessage(playerid, 0xFF0000FF, "Você não está em chamada.");
        return 1;
    }
    new partner = CallPartner[playerid];
    if (IsPlayerConnected(partner)) {
        SendClientMessage(partner, 0xFF0000FF, "Chamada encerrada.");
        CallState[partner] = 0; CallPartner[partner] = -1;
    }
    CallState[playerid] = 0; CallPartner[playerid] = -1;
    SendClientMessage(playerid, 0x00FF00FF, "Chamada encerrada.");
    return 1;
}

CMD:callmsg(playerid, params[]) {
    if (CallState[playerid] != 2 || CallPartner[playerid] == -1) {
        SendClientMessage(playerid, 0xFF0000FF, "Você não está em chamada.");
        return 1;
    }
    new partner = CallPartner[playerid];
    if (!IsPlayerConnected(partner)) {
        SendClientMessage(playerid, 0xFF0000FF, "Parceiro desconectado, encerrando.");
        CallState[playerid] = 0; CallPartner[playerid] = -1;
        return 1;
    }
    new text[128];
    if (!sscanf(params, "s[128]", text)) {
        SendClientMessage(playerid, 0xFF0000FF, "Uso: /callmsg <texto>");
        return 1;
    }
    new buf[256];
    format(buf, sizeof(buf), "[Call %d -> %d] %s", PlayerNumber[playerid], PlayerNumber[partner], text);
    SendClientMessage(partner, 0x00FFFF00, buf);
    SendClientMessage(playerid, 0x00FFFF00, buf);
    return 1;
}

// ----------------- HELPERS -----------------

// encontra playerid por número (retorna -1 se não encontrado ou offline)
public FindPlayerByNumber(number) {
    new i;
    for (i=0; i<MAX_PLAYERS; i++) {
        if (IsPlayerConnected(i) && PlayerNumber[i] == number) return i;
    }
    return -1;
}

// simples wrapper para enviar mensagens formatadas
public SendPlayerMessageTo(playerid, color, const[]) {
    SendClientMessage(playerid, color, const);
    return 1;
}
