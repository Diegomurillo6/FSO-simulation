%CONSTELACIÓN FSO DINÁMICA CON ENRUTAMIENTO AUTOMÁTICO (tipo Starlink)

clear; close all; clc;

%Parámetros de constelación
P = 5;              % nº de planos (RAANs)
M = 8;              % sats por plano
inc_deg = 53;       % inclinación
h  = 550e3;         % altitud
Re = 6378.137e3;    % radio Tierra
a  = Re + h;        % eje semimayor

%Escenario (modo automático)
startTime = datetime(2025,11,13,06,55,0);
stopTime  = startTime + days(1);
sampleTime = 30;    %segundos por paso
sc = satelliteScenario(startTime, stopTime, sampleTime);  % AutoSimulate = true
satelliteScenarioViewer(sc);

%Generar satélites (P planos × M sats)
Nsat = P*M;
sat = cell(1,Nsat);
k = 0;
for p = 0:P-1
    RAAN = p * (360/P);             % RAAN espaciado
    for m = 0:M-1
        k = k+1;
        nu  = m * (360/M);          % fase inicial uniforme
        sat{k} = satellite(sc, a, 0, inc_deg, RAAN, 0, nu, ...
            "Name", sprintf("S%02d_%02d", p+1, m+1), ...
            "OrbitPropagator","two-body-keplerian");
    end
end

%Estaciones terrestres
gs1 = groundStation(sc,  9.85488828548024, -83.90898992873105, "Name","Lupus Unus");
gs2 = groundStation(sc, -3.8872128200168357, -62.94401870271053, "Name","Amazonas");

gimbalGs1 = gimbal(gs1,"MountingAngles",[0;180;0],"MountingLocation",[0;0;-5]);
gimbalGs2 = gimbal(gs2,"MountingAngles",[0;180;0],"MountingLocation",[0;0;-5]);

gs1Tx = transmitter(gimbalGs1,"Name","GS1Tx","MountingLocation",[0;0;1], ...
    "Frequency",30e9,"Power",30);
gaussianAntenna(gs1Tx,"DishDiameter",2);

gs2Rx = receiver(gimbalGs2,"Name","GS2Rx","MountingLocation",[0;0;1], ...
    "GainToNoiseTemperatureRatio",3,"RequiredEbNo",1);
gaussianAntenna(gs2Rx,"DishDiameter",2);

%Terminales satelitales
commonDish = 0.5;
satTxFreq  = 30e9;
satTxPowdB = 15;
G_T_dB     = 3;
ReqEbNo    = 4;

function [gTx,gRx,tx,rx] = addSatTerminals(satObj, name, commonDish, satTxFreq, satTxPowdB, G_T_dB, ReqEbNo)
    gTx = gimbal(satObj,"MountingLocation",[0;1;2]);
    gRx = gimbal(satObj,"MountingLocation",[0;-1;2]);
    rx  = receiver(gRx,"MountingLocation",[0;0;1], ...
        "GainToNoiseTemperatureRatio",G_T_dB, ...
        "RequiredEbNo",ReqEbNo,"Name",name+"_Rx");
    gaussianAntenna(rx,"DishDiameter",commonDish);
    tx  = transmitter(gTx,"MountingLocation",[0;0;1], ...
        "Frequency",satTxFreq,"Power",satTxPowdB,"Name",name+"_Tx");
    gaussianAntenna(tx,"DishDiameter",commonDish);
end

gTx = cell(1,Nsat); gRx = cell(1,Nsat);
sTx = cell(1,Nsat); sRx = cell(1,Nsat);
for i = 1:Nsat
    [gTx{i},gRx{i},sTx{i},sRx{i}] = addSatTerminals(sat{i}, sat{i}.Name, ...
        commonDish, satTxFreq, satTxPowdB, G_T_dB, ReqEbNo);
end

%Nodos y nombres
nodes = [sat, {gs1}, {gs2}];
nodeNames = strings(1, Nsat+2);
for i=1:Nsat, nodeNames(i)=sat{i}.Name; end
nodeNames(Nsat+1) = "Lupus Unus";
nodeNames(Nsat+2) = "Amazonas";

idxLupus    = Nsat+1;
idxAmazonas = Nsat+2;

terminals = struct("gTx",gTx,"gRx",gRx,"tx",sTx,"rx",sRx);

%Conectividad precomputada (todos contra todos)
N = numel(nodes);
Access = cell(N,N);
for i = 1:N
    for j = i+1:N
        Access{i,j} = access(nodes{i}, nodes{j});
        Access{j,i} = Access{i,j};
    end
end

%FUNCIONES AUXILIARES (BFS y utilidades)
function path = bfsPath(A, s, d)
    Nloc = size(A,1);
    visited = false(1,Nloc); prev = zeros(1,Nloc);
    q = s; visited(s)=true;
    while ~isempty(q)
        u = q(1); q(1) = [];
        if u==d, break; end
        for v=find(A(u,:))
            if ~visited(v)
                visited(v)=true; prev(v)=u; q(end+1)=v; %#ok<AGROW>
            end
        end
    end
    if ~visited(d), path=[]; return; end
    path=d; while path(1)~=s, path=[prev(path(1)), path]; end %#ok<AGROW>
end

%Post-proceso: Conectividad E2E (Amazonas a Lupus) a lo largo del día

%Obtener un vector temporal de referencia (mismas muestras para todo)
% Tomamos el primero access válido y extraemos su tvec
refFound = false;
for ii = 1:N
    for jj = ii+1:N
        [status_ref, tvec_ref] = accessStatus(Access{ii,jj});
        if ~isempty(tvec_ref)
            refFound = true;
            break;
        end
    end
    if refFound, break; end
end
if ~refFound
    error('No se pudo obtener vector temporal de referencia de accessStatus().');
end

%Pre-extraer estados de visibilidad para cada par en el mismo tvec
%(si algún access tiene tvec distinto, se realinea)
statusCell = cell(N,N);
for i = 1:N
    for j = i+1:N
        [sij, tij] = accessStatus(Access{i,j});
        if isempty(tij)
            sAligned = false(size(tvec_ref));
        else
            %Alinear por igualdad exacta de marcas de tiempo
            [lia, locb] = ismember(tvec_ref, tij);
            sAligned = false(size(tvec_ref));
            sAligned(lia) = sij(locb(lia));
        end
        statusCell{i,j} = sAligned;
        statusCell{j,i} = sAligned;
    end
end

%Para cada instante k, construir grafo y comprobar ruta E2E
K = numel(tvec_ref);
connected = false(K,1);
for k = 1:K
    A = false(N,N);
    for i = 1:N
        for j = i+1:N
            if statusCell{i,j}(k)
                A(i,j) = true; A(j,i) = true;
            end
        end
    end
    pathIdx = bfsPath(A, idxAmazonas, idxLupus);
    connected(k) = ~isempty(pathIdx);
end

%Convertir 'connected(t)' en intervalos [inicio, fin]
edges = diff([false; connected; false]);  % +1: start, -1: end
starts = find(edges==1);
ends   = find(edges==-1) - 1;

t_start = tvec_ref(starts);
t_end   = tvec_ref(ends);

%Graficar timeline de conectividad E2E
figure; hold on; grid on;
for r = 1:numel(t_start)
    plot([t_start(r) t_end(r)], [1 1], 'LineWidth', 8);  % una barra por intervalo
end
datetick('x','HH:MM'); xlim([tvec_ref(1) tvec_ref(end)]);
yticks([]); ylim([0.5 1.5]);
xlabel('Hora UTC'); title('Conectividad E2E Amazonas \leftrightarrow Lupus Unus');
if isempty(t_start)
    text(mean(xlim), 1, 'Sin conectividad E2E en el período simulado', ...
        'HorizontalAlignment','center','VerticalAlignment','middle');
end
hold off;

disp(['Intervalos E2E encontrados: ', num2str(numel(t_start))]);
for r = 1:numel(t_start)
    fprintf('%02d) %s  →  %s\n', r, string(t_start(r)), string(t_end(r)));
end
