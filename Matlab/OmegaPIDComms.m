%instrhwinfo('serial')
%instrfind

%% User Adjustable parameters. Do not make modifications below this block
experimentStartTime = [2022 5 24 19 12 00];

TemperatureSetPoint = 40;   % C
SessionDuration = 8;        % Duration in hours
NumberOfStimuli = 10;       % How many times to deliver the stimulus during a session
MinTimeBetweenStims = 15;   % Minimum time (in minutes) required between consecutive stimuli starts
StimDuration = 10;          %Duration of each stimulus in seconds

if MinTimeBetweenStims <= StimDuration
    warning("Stim duration too long, or minimum time between consecutive stims too short. Adjust parameters")
end

% Do not modify below this line

%% 
% Make serial object and open connection
s=serialport('com5', 9600, 'stopbit', 1, 'databits', 8, 'parity', 'none');%this needs to be the port which shows Silicon Labs bridge in Windows device manager
%set(s, 'stopbit', 1, 'databits', 8, 'parity', 'none', 'baudrate', 9600)%make identical to those on the controller
%fopen(s);

% PID controller parameters
%MODBUS over serial implementation
controllerParams.address = '01'; %device address
controllerParams.setpointRegister = ['10'; '01']; %address of the register that holds the setpoint value
controllerParams.processValueRegister = ['10'; '00']; %read current temp. not used for now.
controllerParams.unitDisplaySelectionRegister = ['08'; '11']; %change units from F to C
controllerParams.runStopRegister = ['08'; '14']; %start/stop register

% Create Log file
filename = [datestr(clock, 29), '_logfile.txt'];
fileID = fopen(filename, 'w');
fprintf(fileID, '%s %10s %8s\n', 'Date', 'Time', 'Temp');

% Stimulation Profile

% Generating random start times until able to produce a set that satisfies
% minimum timing between stimuli for the specified number of stims.
% Perhaps bad practice to place a pseudo random function inside a while loop?
% Can potentially get into trouble if minimum time between stimuli is set too long.

intervalBetweenStims = zeros(1, NumberOfStimuli);
counter=1;
while min(intervalBetweenStims)<MinTimeBetweenStims
    proposedStimTimes = sort(round(rand(1, NumberOfStimuli)*SessionDuration*60));
    intervalBetweenStims = diff(proposedStimTimes);
    counter=counter+1;
    % Break out of the loop if can't produce a set of start times after a
    % reasonable number of attempts
    if counter > 1000
        error('Stim parameters set too restrictively. Increase session duration, or reduce number of stims, or reduce min required time between stims')
        break
    end
end

%stimStruct.setpoint = TemperatureSetPoint*ones(1, NumberOfStimuli); %desired temp
stimStruct.setpoint = [20 25 30 35 40 37 33 31 27 29];
stimStruct.stimDuration = StimDuration*ones(1, NumberOfStimuli); %temp on time
stimStruct.startTimes = proposedStimTimes; 
stimStruct.controlParams = controllerParams;
stimStruct.serial = s;
stimStruct.fileID = fileID;

disp("Stimuli will be presented at: " + datestr(datetime(experimentStartTime) + minutes(proposedStimTimes)))

% %% Start timer for execution loop
% t = timer;
% t.StartDelay = 0;
% t.TimerFcn = @(~, ~) stimulusLoop(stimStruct);
% t.StopFcn = {@(~, ~) cleanUpPID(stimStruct, t)};
% %t.StartFcn = {@(~, ~) fclose(s); @(~, ~) disp('end of run')};
% 
% startat(t, experimentStartTime);
% %delete(t) %delete timer object
% 
% %startPID

%% Create timer objects, execute stims
% Create an array of timers. When a timer fires, it changes the temperature
% to the subsequent value from the stimStruct
for ii = 1:NumberOfStimuli
    timerArray(ii) = timer('TimerFcn', @(~,~)presentStimulus(stimStruct, ii),...
        'StartFcn', @(~,~)disp("Started at: " + datestr(datetime('now'))));
end
%startat(timerArray, datetime('now') + seconds(proposedStimTimes))
startat(timerArray, datetime(experimentStartTime) + seconds(proposedStimTimes))

%Create one more timer to execute clean-up steps after all the other timers
%run.
% t=timer;
% t.TimerFcn = @(~, ~) cleanUp();
% startat(t, datetime(experimentStartTime) + seconds(proposedStimTimes(end)+1))


%Do this after all timers have executed
disp(datestr(datetime('now')) + ": delivered " + NumberOfStimuli + " stimuli")

%% Make RTU Message
% change_temp_units(s, controllerParams, 'C');
% change_temp(s, controllerParams, temperature);
% startPID(s, controllerParams);
% stopPID(s, controllerParams);


% %% Clean up
% % Check if all timers ran. If so, close the log file and the connection to
% % PID. Print out message to terminal
% %fclose(s); %close serial port
% function [] = cleanUp()
%     stop(timerfind);
%     delete(timerfind);
%     fclose(fileID);
% end





