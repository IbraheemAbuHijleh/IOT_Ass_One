
%% 1. System Parameters


% Sensor parameters
sensorSpecs = struct(...
    'soilSensor', struct('activePower', 5, 'idlePower', 0.1),... % in mW
    'envSensor', struct('activePower', 3, 'idlePower', 0.1));     % in mW

% Communication parameters
commSpecs = struct(...
    'protocolType', 'MQTT',...
    'transmitPower', 50,...    % mW
    'receivePower', 30,...     % mW
    'dataPacketSize', 128);   % bytes

powerSpecs = struct(...
    'mcuActivePower', 10,...    % mW
    'mcuSleepPower', 0.01,...   % mW
    'supplyVoltage', 3.3);      % V


% Simulation parameters
simulationHours = 24;         % hours
senseInterval = 900;          % seconds (15 minutes)

%% 2. Data Generation (Simulating Sensor Readings)
% Generate realistic sensor data patterns
hourMarks = 1:simulationHours;
temperature = 15 + 10*sin(2*pi*hourMarks/24) + randn(1,simulationHours)*0.5; % °C
humidityLevel = 50 + 30*sin(2*pi*(hourMarks+6)/24) + randn(1,simulationHours)*2; % %
atmPressure = 1010 + randn(1,simulationHours)*0.5; % kPa
moistureLevel = 30 + 20*sin(2*pi*(hourMarks+12)/24) + randn(1,simulationHours)*2; % %

timeVector = linspace(0, simulationHours*3600, simulationHours*60)'; % 1 minute resolution
tempSeries = interp1(hourMarks*3600, temperature, timeVector);
humiditySeries = interp1(hourMarks*3600, humidityLevel, timeVector);
pressureSeries = interp1(hourMarks*3600, atmPressure, timeVector);
moistureSeries = interp1(hourMarks*3600, moistureLevel, timeVector);

sensorTable = timetable(seconds(timeVector), ...
    tempSeries(:), humiditySeries(:), ...
    pressureSeries(:), moistureSeries(:), ...
    'VariableNames', {'Temperature', 'Humidity', 'Pressure', 'SoilMoisture'});

%% 3. Baseline Power Consumption Simulation
fprintf('Running baseline simulation...\n');

energyUsageBaseline = zeros(simulationHours, 1);

for hr = 1:simulationHours
    if hr >=6 && hr <=20
        sampleCycles = 4;
    else
        sampleCycles = 2;
    end

    for iter = 1:sampleCycles
        sensingDuration = 10; % seconds
        energySensing = (sensorSpecs.soilSensor.activePower + ...
                         sensorSpecs.envSensor.activePower + ...
                         powerSpecs.mcuActivePower) * sensingDuration;

        processDuration = 5; % seconds
        energyProcessing = powerSpecs.mcuActivePower * processDuration;

        if rand > 0.1 % 90% success rate
            txRxTime = 0.5 + 0.1;
            energyComm = commSpecs.transmitPower*0.5 + commSpecs.receivePower*0.1;
        else
            txRxTime = (0.5 + 0.1)*2;
            energyComm = (commSpecs.transmitPower*0.5 + commSpecs.receivePower*0.1)*2;
        end

        fullCycle = 3600/sampleCycles; % seconds
        sleepDuration = fullCycle - (sensingDuration + processDuration + txRxTime);
        energySleep = powerSpecs.mcuSleepPower * sleepDuration;

        totalEnergy = energySensing + energyProcessing + energyComm + energySleep;
        energyUsageBaseline(hr) = energyUsageBaseline(hr) + totalEnergy;
    end
end

%% 4. Optimized Power Consumption Simulation
fprintf('Running optimized simulation...\n');

energyUsageOptimized = zeros(simulationHours, 1);
lastMoisture = moistureLevel(1);
lastTemp = temperature(1);
lastHumid = humidityLevel(1);

for hr = 1:simulationHours
    if hr > 1
        deltaMoisture = abs(moistureLevel(hr) - lastMoisture);
        deltaEnv = max([abs(temperature(hr) - lastTemp), abs(humidityLevel(hr) - lastHumid)]);
        deltaMax = max(deltaMoisture, deltaEnv);
    else
        deltaMax = 1;
    end

    if deltaMax > 2
        sampleCycles = 6;
    elseif deltaMax > 0.5
        sampleCycles = 3;
    else
        sampleCycles = 1;
    end

    lastMoisture = moistureLevel(hr);
    lastTemp = temperature(hr);
    lastHumid = humidityLevel(hr);

    for iter = 1:sampleCycles
        if mod(iter,2) == 0
            activeSensorPower = sensorSpecs.soilSensor.activePower + ...
                                sensorSpecs.envSensor.idlePower;
        else
            activeSensorPower = sensorSpecs.envSensor.activePower + ...
                                sensorSpecs.soilSensor.idlePower;
        end

        sensingDuration = 5; % seconds
        energySensing = (activeSensorPower + powerSpecs.mcuActivePower) * sensingDuration;

        processDuration = 3; % seconds
        energyProcessing = powerSpecs.mcuActivePower * processDuration;

        if rand > 0.15
            txRxTime = 0.4 + 0.1;
            energyComm = commSpecs.transmitPower*0.4 + commSpecs.receivePower*0.1;
        else
            txRxTime = (0.4 + 0.1)*1.5;
            energyComm = (commSpecs.transmitPower*0.4 + commSpecs.receivePower*0.1)*1.5;
        end

        fullCycle = 3600/sampleCycles;
        sleepDuration = fullCycle - (sensingDuration + processDuration + txRxTime);
        energySleep = powerSpecs.mcuSleepPower * sleepDuration;

        totalEnergy = energySensing + energyProcessing + energyComm + energySleep;
        energyUsageOptimized(hr) = energyUsageOptimized(hr) + totalEnergy;
    end
end

%% 5. Results Visualization
baselineWh = energyUsageBaseline / 3600;
optimizedWh = energyUsageOptimized / 3600;

figure;
subplot(2,1,1);
plot(1:simulationHours, baselineWh, 'b-o', 'LineWidth', 1.5);
hold on;
plot(1:simulationHours, optimizedWh, 'r-s', 'LineWidth', 1.5);
xlabel('Time (hours)');
ylabel('Energy Consumption (mWh)');
title('Hourly Energy Consumption Comparison');
legend('Baseline', 'Optimized', 'Location', 'northwest');
grid on;

subplot(2,1,2);
plot(1:simulationHours, cumsum(baselineWh), 'b-o', 'LineWidth', 1.5);
hold on;
plot(1:simulationHours, cumsum(optimizedWh), 'r-s', 'LineWidth', 1.5);
xlabel('Time (hours)');
ylabel('Cumulative Energy (mWh)');
title('Cumulative Energy Consumption');
legend('Baseline', 'Optimized', 'Location', 'northwest');
grid on;

totalBaselineEnergy = sum(baselineWh);
totalOptimizedEnergy = sum(optimizedWh);
energySaving = (totalBaselineEnergy - totalOptimizedEnergy) / totalBaselineEnergy * 100;

fprintf('\n--- Results ---\n');
fprintf('Total baseline energy: %.2f mWh\n', totalBaselineEnergy);
fprintf('Total optimized energy: %.2f mWh\n', totalOptimizedEnergy);
fprintf('Energy savings: %.1f%%\n', energySaving);


