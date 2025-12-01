// iFood Mission - SA-MP Pawn (server-side)
// Coloque este script num include separado e chame as funções no seu gamemode ou registre o comando /ifood

new const MAX_DEST = 8;
new Float:DestX[MAX_DEST] = {-1796.0, -1050.0, -1570.0, 425.0, 1350.0, 2200.0, 400.0, -500.0};
new Float:DestY[MAX_DEST] = {444.0, 344.0, 2800.0, -1110.0, -1700.0, -1600.0, 1850.0, 600.0};
new Float:DestZ[MAX_DEST] = {12.0, 25.0, 10.0, 23.0, 50.0, 12.0, 9.0, 14.0};

new PlayerOnMission[MAX_PLAYERS];
new MissionVehicle[MAX_PLAYERS];
new MissionBlip[MAX_PLAYERS];
new CurrentDest[MAX_PLAYERS];
new DeliveriesDone[MAX_PLAYERS];
new MoneyEarned[MAX_PLAYERS];
new XPgained[MAX_PLAYERS];

public OnPlayerCommandText(playerid, cmdtext[])
{
    if (strcmp(cmdtext, "/ifood", true) == 0)
    {
        StartIFoodMission(playerid);
        return 1;
    }
    return 0;
}

StartIFoodMission(playerid)
{
    if (PlayerOnMission[playerid])
    {
        SendClientMessage(playerid, 0xFFFF00FF, "Você já está em uma missão iFood!");
        return 0;
    }
    PlayerOnMission[playerid] = 1;
    DeliveriesDone[playerid] = 0;
    MoneyEarned[playerid] = 0;
    XPgained[playerid] = 0;

    // escolhe veículo aleatório (models: BMX 509, Faggio 462, PCJ 353, FCR 541)
    new vehModels[4] = {509, 462, 353, 541};
    new idx = random(4);
    new model = vehModels[idx];

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new Float:spawnx = px + 3.0;
    new spawny = py;
    new spawnz = pz;

    MissionVehicle[playerid] = CreateVehicle(model, spawnx, spawny, spawnz, 0.0, 0, 0);
    PutPlayerInVehicle(playerid, MissionVehicle[playerid], VEHICLE_DRIVER);

    // escolhe destino
    CurrentDest[playerid] = random(MAX_DEST);
    MissionBlip[playerid] = CreateBlipForCoord(DestX[CurrentDest[playerid]], DestY[CurrentDest[playerid]], DestZ[CurrentDest[playerid]]);

    SendClientMessage(playerid, 0x00FF00FF, "Missão iFood iniciada! Dirija até o blip e use /entregar quando estiver próximo.");

    // iniciar timer de verificação (server-side) - checa a cada 2s
    SetTimerEx("IFood_Check", 2000, true, "i", playerid);
    return 1;
}

public IFood_Check(playerid)
{
    if (!PlayerOnMission[playerid]) return 1; // continue timer mas sem ação

    // checar se veículo existe
    if (!IsPlayerConnected(playerid) || !IsValidPlayer(playerid))
    {
        StopIFoodMission(playerid, 0);
        return 1;
    }

    if (!IsPlayerInAnyVehicle(playerid))
    {
        SendClientMessage(playerid, 0xFF0000FF, "Saia do veículo por muito tempo e a missão falhará!");
        // opcional: contar tempo fora do veículo
    }

    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new Float:dx = DestX[CurrentDest[playerid]] - px;
    new Float:dy = DestY[CurrentDest[playerid]] - py;
    new Float:dz = DestZ[CurrentDest[playerid]] - pz;
    new Float:dist2 = dx*dx + dy*dy + dz*dz;
    if (dist2 < 100.0) // dentro de ~10m
    {
        SendClientMessage(playerid, 0x00FFFF00, "Você está próximo ao destino. Use /entregar para completar.");
    }
    return 1;
}

CMD:entregar(playerid, params[])
{
    if (!PlayerOnMission[playerid]) { SendClientMessage(playerid, 0xFFFF00FF, "Você não está em missão."); return 1; }
    new Float:px, Float:py, Float:pz;
    GetPlayerPos(playerid, px, py, pz);
    new Float:dx = DestX[CurrentDest[playerid]] - px;
    new Float:dy = DestY[CurrentDest[playerid]] - py;
    new Float:dz = DestZ[CurrentDest[playerid]] - pz;
    new Float:dist2 = dx*dx + dy*dy + dz*dz;
    if (dist2 > 100.0) { SendClientMessage(playerid, 0xFF0000FF, "Você está muito longe do local de entrega."); return 1; }

    // recompensa
    new reward = random(40) + 40; // 40..79
    GivePlayerMoney(playerid, reward);
    MoneyEarned[playerid] += reward;
    XPgained[playerid] += 10;
    DeliveriesDone[playerid]++;

    SendClientMessage(playerid, 0x00FF00FF, "Entrega concluída! Dinheiro ganho: $%d", reward);

    // remover blip e escol