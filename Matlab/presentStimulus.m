function [] = presentStimulus(stimStruct, index)
    %2022 PVG: This is the updated version based on change_temp.m

    baseLineTemp = 15; %Default PID temp during 'off' state
    
    changeTemp(stimStruct.setpoint(index))
    startPID();
   
    %Create and start timer which will turn off the stimulus
    t = timer;
    t.StartDelay = stimStruct.stimDuration(index);
    t.TimerFcn = @(~,~)stopPID();
    t.StopFcn = @(~,~)cleanUp();
    start(t)
    
    function [] = changeTemp (tempSetPoint)
        %This function updates the temp setting register. It does not change
        %the run register. ie, if the register is set to zero, changing the
        %temp will adjust the set point, but it will not start the PID.
        temp_setpoint_hex = dec2hex(tempSetPoint*10, 4);  

        function_code = '06'; %write word to register
        
        message_less_CRC = [stimStruct.controlParams.address; 
            function_code; 
            stimStruct.controlParams.setpointRegister;
            [temp_setpoint_hex(1:2); temp_setpoint_hex(3:4)]]; %split setpoint into bytes
        
        %Third party CRC function
        temp_dec_message = hex2dec(message_less_CRC);
        amsg = append_crc(temp_dec_message); %original message with two CRC bytes at the end
        
        write(stimStruct.serial, amsg, "uint8")
        disp(datestr(datetime('now')) + " Changed Temperature to: " + tempSetPoint + "C" )
        pause(.05); %to avoid clobbering the PID controller with subsequent commands
    end
    
    function [] = stopPID()
        changeTemp(baseLineTemp) % change temp back to baseline

        %disable PID
        function_code = '05'; %write 1 bit to register
        data_to_write = ['00';'00']; %Stop
        
        message_less_CRC = [stimStruct.controlParams.address; 
            function_code; 
            stimStruct.controlParams.runStopRegister; %Which register to write to
            data_to_write];
        
        %Third party CRC function
        temp_dec_message = hex2dec(message_less_CRC);
        amsg = append_crc(temp_dec_message); %original message with two CRC bytes at the end
        
        write(stimStruct.serial, amsg, "uint8") 
        %disp(datestr(datetime('now')) + " Changed Temperature to: " + baseLineTemp + "C, Stopping PID" ) 
        disp(datestr(datetime('now')) + " Stopping PID" ) 
    end

    function [] = startPID()
        function_code = '05'; %write 1 bit to register
        data_to_write = ['FF';'00']; %Start
        
        message_less_CRC = [stimStruct.controlParams.address;
            function_code; %Write 1 bit
            stimStruct.controlParams.runStopRegister; %To start/stop register
            data_to_write];
        
        %Third party CRC function
        temp_dec_message = hex2dec(message_less_CRC);
        amsg = append_crc(temp_dec_message); %original message with two CRC bytes at the end
        
        write(stimStruct.serial, amsg, "uint8")
        disp(datestr(datetime('now')) + " Starting PID for next " + stimStruct.stimDuration(index) + " seconds" )

        %Append log file with timing information
        currentTimeVec = clock;
        fprintf(stimStruct.fileID, '%s\n', [datestr(currentTimeVec, 23), ' ', datestr(currentTimeVec, 13)]);
        %string = sprintf('Starting PID for %.1f seconds', stimStruct.stimDuration(index));
    end

    function [] = cleanUp()
    stop(t)
    delete(t)
    end
end

