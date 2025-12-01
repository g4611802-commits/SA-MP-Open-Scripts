// Wheelie System - SA:MP (PAWN)
// Autor: Criado por AWSA (ajuste livre)
// Requer: SA-MP com SetVehicleAngularVelocity / SetVehicleVelocity

new bool:g_bWheelieEnabled[MAX_PLAYERS];
new Float:g_fWheelieTimerDelay = 50.0; // ms (timer tick)
new Float:g_fWheeliePower = 0.06;      // força angular máxima (ajuste)
new Float:g_fLiftPower = 0.18;         // impulso vertical quando inicia empinar
new Float:g_fSpeedRequired = 3.0;      // velocidade mínima (m/s) para permitir wheelie
new Float:g_fSmoothing = 0.85;         // 0..1, quanto maior mais suave/lerdo para mudar a inclinação
new Float:g_fReleaseRecovery = 0.15;   // força de recuperação quando soltar o acelerador

// Lista de modelos considerados "motos" (IDs padrão; adicione/retire conforme desejar)
new const BIKE_MODELS[] = { 581,582,586,487,509,521,522,523,541,576,0 }; // termine com 0

public OnGameModeInit()
{
    SetTimerEx("WheelieTick", Round(g_fWheelieTimerDelay), true, "0"); 
    print("Wheelie System carregado.");
    return 1;
}

// Comando para toggle
CMD:wheelie(playerid, params[])
{
    g_bWheelieEnabled[playerid] = !g_bWheelieEnabled[playerid];
    SendClientMessage(playerid, 0x00DD00AA, g_bWheelieEnabled[playerid] ? "Wheelie: ON" : "Wheelie: OFF");
    return 1;
}

// Detecta mudanças de keys (usamos para saber quando o player pressiona/solta acelerar)
public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    // Nada aqui preciso para este script, o timer vai consultar o estado via GetPlayerKeys.
    return 1;
}

// Util: verifica se modelo é moto
forward IsBikeModel(modelid);
stock IsBikeModel(modelid)
{
    new i=0;
    while (BIKE_MODELS[i])
    {
        if (BIKE_MODELS[i] == modelid) return 1;
        i++;
    }
    return 0;
}

// Timer principal - aplica wheelie a cada tick
public WheelieTick()
{
    new playerid;
    for (playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        if (!IsPlayerConnected(playerid)) continue;
        if (!g_bWheelieEnabled[playerid]) continue;

        if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER) continue;
        new vehicle = GetPlayerVehicleID(playerid);
        if (vehicle == INVALID_VEHICLE_ID) continue;

        // apenas motoristas na rota principal (assento 0)
        new seat; GetPlayerVehicleSeat(playerid, seat);
        if (seat != 0) continue;

        // checar se modelo é bike (opcional)
        new model = GetVehicleModel(vehicle);
        if (!IsBikeModel(model)) continue;

        // pega velocidade vetorial
        Float:vx, Float:vy, Float:vz;
        GetVehicleVelocity(vehicle, vx, vy, vz);
        Float:speed = floatsqroot(vx*vx + vy*vy + vz*vz); // magnitude

        // exige velocidade minima
        if (speed < g_fSpeedRequired) continue;

        // lê keys atuais do jogador
        new keys = 0;
        GetPlayerKeys(playerid, keys, _); // usamos apenas keys on vehicle (bitmask)

        // KEY_SPRINT é aceleração em veículo (W / espaço) - ver constants include Keys
        static const KEY_ACCEL = 8; // corresponde a KEY_SPRINT mapeado para vehicle accelerate; se preferir use constantes do include Keys

        // obtem valor alvo de "empinar" baseado em se está segurando acelerar
        // se segurando -> target angular velocity negativa no eixo X (levantar frente)
        static Float g_fCurrentAng[MAX_VEHICLES];
        if (keys & KEY_ACCEL)
        {
            // magnitude alvo proporcional à velocidade (mais rapido -> + empinada)
            Float:target = - ( g_fWheeliePower * clampf(speed / 30.0, 0.4, 1.6) ); // escala por speed, clamp para limitar
            // suavizar transição (exponential smoothing)
            g_fCurrentAng[vehicle] = (g_fSmoothing * g_fCurrentAng[vehicle]) + ((1.0 - g_fSmoothing) * target);

            // ao iniciar (transicao de 0 para negativo) aplica um impulso vertical pro lift
            if (g_fCurrentAng[vehicle] < -0.01 && fabs(g_fCurrentAng[vehicle]) < fabs(target) + 0.005)
            {
                // dá um pequeno impulso vertical
                SetVehicleVelocity(vehicle, vx, vy, vz + g_fLiftPower);
            }
        }
        else
        {
            // liberar - voltar pro chão com recovery suave
            g_fCurrentAng[vehicle] = (g_fSmoothing * g_fCurrentAng[vehicle]) + ((1.0 - g_fSmoothing) * g_fReleaseRecovery);
            // quando muito perto do 0, zera para estabilidade
            if (fabs(g_fCurrentAng[vehicle]) < 0.02) g_fCurrentAng[vehicle] = 0.0;
        }

        // aplica angular velocity (X, Y, Z) - X = pitch
        // nota: SetVehicleAngularVelocity exige versão SA-MP 0.3b+ / open.mp
        SetVehicleAngularVelocity(vehicle, g_fCurrentAng[vehicle], 0.0, 0.0);
    }

    return 1;
}

// Helpers
stock Float:clampf(Float:v, Float:lo, Float:hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}
stock Float:floatsqroot(Float:v)
{
    if (v <= 0.0) return 0.0;
    return sqrt(v);
}
