classdef pumps < handle
    % Class for controlling syringe pumps with RS-232 connectivity.
    % Implementation is designed to be modular to enable operation of pumps
    % from a variety of manufacturers.
    %
    % Currently only includes support for New Era syringe pumps.
    %
    % TO DO:
    % * Finish support for all syringe pump commands.
    % * Support for safe mode interface.
    % * Support for programmable pumping
    % * Initialize pumping limits based on syringe properties table
    % * Determine whether rate command will execute properly
    % 
    % Based on arduino.m master/slave interface for Matlab by ...
    % Giampiero Campa.
    %
    % Author: Lloyd Ung
    % created: 2012-04-15
    % last modified: 2012-10-11

    %% Class Constants
    properties (Constant = true)
        % Serial link parameters
        newEraSerialConfig = struct('BaudRate',19200,'DataBits',8,...
            'FlowControl','none','Parity','none','StopBits',1,...
            'Terminator','CR');

        % Command String
        newEraCommandString = struct('diameter','DIA','run','RUN',...
            'stop','STP','rate','RAT','volume','VOL','direction','DIR',...
            'dispensed','DIS','clearDispense','CLD','safe','SAF',...
            'version','VER');
        
        % Syringe data table
        syringeData = {};
        
        % Constants
        serialWaitTime = 0.5; % units of seconds
    end

    %% Class properties    
    % Private class properties
%     properties (SetAccess = private, GetAccess = private)
    properties
        % Serial handle
        serialHandle = [];
        
        % Command String - holds the structure of commands appropriate for
        % a certain model of pump.
        cStr = [];
    end

    %% Class Methods
    methods
        % Class creator - initializes serial link.
        function obj = pumps(port)
            % Check input string
            if ~ischar(port)
                error(['The input argument must be a string, e.g. '...
                    '''COM8'' ']);
            end
            
            % check if we are already connected
            if isa(obj.serialHandle,'serial') && ...
                    isvalid(obj.serialHandle) && ...
                    strcmpi(get(obj.serialHandle,'Status'),'open')
                disp('Desired port is not available.');
                return;
            end
            
            % check whether serial port is currently used by MATLAB
            if ~isempty(instrfind({'Port'},{port})),
                disp(['The port ' port ' is already used by MATLAB']);
                error(['Port ' port ' already used by MATLAB']);
            end
            
            % Choose the pump type
            serialConfig = obj.newEraSerialConfig;
            obj.cStr = obj.newEraCommandString;
            
            % define serial object and configure according to pumps.
            obj.serialHandle = serial(port,'BaudRate',...
                serialConfig.BaudRate,'DataBits',serialConfig.DataBits,...
                'FlowControl',serialConfig.FlowControl,...
                'Parity',serialConfig.Parity,...
                'StopBits',serialConfig.StopBits,...
                'Terminator',serialConfig.Terminator);
            
            % Connect port
            try
                fopen(obj.serialHandle);
            catch ME,
                disp(ME.message)
                delete(obj);
%                 obj = [];
                error(['Could not open port: ' port]);
            end

            % Wait to ensure connection is valid.
            fprintf(1,'Attempting connection ..');
            for i=1:4,
                fprintf(1,'.');
                pause(0.5);
            end
            fprintf(1,'\n');
            
            % Code for verifying connection goes here.

            disp('Port successfully connected !');            
        end

        % delete pump object, closing serial
        function delete(obj)
            % Terminate the serial link.
            % if it is a serial, valid and open then close it
            if isa(obj.serialHandle,'serial') && ...
                    isvalid(obj.serialHandle) && ...
                    strcmpi(get(obj.serialHandle,'Status'),'open')
                fclose(obj.serialHandle);
            end
            
            % if it's an object delete it
            if isobject(obj.serialHandle),
                delete(obj.serialHandle);
            end
        end
        
        function pumpOutput = clearDispense(obj,direction,varargin)
            % Set/Query volume to dispense
            commandString = obj.cStr.clearDispense;
            
            % Set direction to clear
            if strcmpi(direction,'INF') || strcmpi(direction,'WDR')
                valueString = [' ' upper(direction)];
            else
                error('Not a valid direction.\n');
            end
            
            commandString = [commandString valueString];
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if nargin > 2
                pumpOutput = obj.interface(commandString,varargin{1});
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        function pumpOutput = diameter(obj,varargin)
            % Set/Query diameter.  Units are in millimeters only.
            commandString = obj.cStr.diameter;
            
            % Optional input arguments must be listed as property-value 
            % pairs.  Use these pairs to modify the command string.
            address = [];
            valueString = [];
            for k = 1:2:length(varargin)
                switch true
                    case strcmpi(varargin{k},'value')
                        % Convert new value to string and append to command
                        % string.  Assumes floating points with 4 sig figs
                        % and max of 3 decimal precision.
                        if varargin{k+1} >= 100
                            formatString = '%4.1f';
                        elseif varargin{k+1} >= 10
                            formatString = '%4.2f';
                        else
                            formatString = '%4.3f';
                        end
                        
                        % Add the string with new diameter to the command
                        valueString = [ ' ' num2str(varargin{k+1},...
                            formatString)];
                    case strcmpi(varargin{k},'address')
                        address = varargin{k+1};
                    otherwise
                        error(['Property-Value pair ' num2str(k) ...
                            ' is not a valid property for diameter.\n']);
                end
            end
            
            commandString = [commandString valueString];
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if ~isempty(address)
                pumpOutput = obj.interface(commandString,address);
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        function pumpOutput = direction(obj,varargin)
            % Set/Query volume to dispense
            commandString = obj.cStr.direction;
            
            % Optional input arguments must be listed as property-value 
            % pairs.  Use these pairs to modify the command string.
            address = [];
            valueString = [];
            for k = 1:2:length(varargin)
                switch true
                    case strcmpi(varargin{k},'value')
                        % If we have a valid direction string
                        if strcmpi(varargin{k+1},'INF') || ...
                            strcmpi(varargin{k+1},'WDR') || ...
                            strcmpi(varargin{k+1},'REV')
                            valueString = [' ' upper(varargin{k+1})];
                        end
                    case strcmpi(varargin{k},'address')
                        address = varargin{k+1};
                    otherwise
                        error(['Property-Value pair ' num2str(k) ...
                            ' is not a valid property for direction.\n']);
                end
            end
            
            commandString = [commandString valueString];
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if ~isempty(address)
                pumpOutput = obj.interface(commandString,address);
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        function pumpOutput = dispensed(obj,varargin)
            % Query volume dispensed.
            commandString = obj.cStr.dispensed;
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if nargin > 1
                pumpOutput = obj.interface(commandString,varargin{1});
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        function pumpOutput = rate(obj,varargin)
            % Set/Query rate.  Units can be set.
            commandString = obj.cStr.rate;
            
            % Optional input arguments must be listed as property-value 
            % pairs.  Use these pairs to modify the command string.
            address = [];
            valueString = [];
            unitString = [];
            for k = 1:2:length(varargin)
                switch true
                    case strcmpi(varargin{k},'value')
                        % Convert new value to string and append to command
                        % string.  Assumes floating points with 4 sig figs
                        % and max of 3 decimal precision.
                        if varargin{k+1} >= 1000
                            formatString = '%4.0f';
                        elseif varargin{k+1} >= 100
                            formatString = '%4.1f';
                        elseif varargin{k+1} >= 10
                            formatString = '%4.2f';
                        else
                            formatString = '%4.3f';
                        end
                        
                        % Add the string with new diameter to the command
                        valueString = [ ' ' num2str(varargin{k+1},...
                            formatString)];
                    case strcmpi(varargin{k},'unit')
                        % If we have a valid unit string:
                        if strcmpi(varargin{k+1},'UM') || ...
                            strcmpi(varargin{k+1},'MM') || ...
                            strcmpi(varargin{k+1},'UH') || ...
                            strcmpi(varargin{k+1},'MH')
                            unitString = [' ' upper(varargin{k+1})];
                        end
                    case strcmpi(varargin{k},'address')
                        address = varargin{k+1};
                    otherwise
                        error(['Property-Value pair ' num2str(k) ...
                            ' is not a valid property for diameter.\n']);
                end
            end
            
            commandString = [commandString valueString unitString];
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if ~isempty(address)
                pumpOutput = obj.interface(commandString,address);
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        function pumpOutput = run(obj,varargin)
            % Send command to run the pump.
            commandString = obj.cStr.run;
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if nargin > 1
                pumpOutput = obj.interface(commandString,varargin{1});
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        function pumpOutput = stop(obj,varargin)
            % Send command to stop the pump.
            commandString = obj.cStr.stop;
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if nargin > 1
                pumpOutput = obj.interface(commandString,varargin{1});
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        function pumpOutput = version(obj,varargin)
            % Query pump firmware version
            commandString = obj.cStr.version;
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if nargin > 1
                pumpOutput = obj.interface(commandString,varargin{1});
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        function pumpOutput = volume(obj,varargin)
            % Set/Query volume to dispense
            commandString = obj.cStr.volume;
            
            % Optional input arguments must be listed as property-value 
            % pairs.  Use these pairs to modify the command string.
            address = [];
            valueString = [];
            for k = 1:2:length(varargin)
                switch true
                    case strcmpi(varargin{k},'value')
                        % Convert new value to string and append to command
                        % string.  Assumes floating points with 4 sig figs
                        % and max of 3 decimal precision.
                        if varargin{k+1} >= 100
                            formatString = '%4.1f';
                        elseif varargin{k+1} >= 10
                            formatString = '%4.2f';
                        else
                            formatString = '%4.3f';
                        end
                        
                        % Add the string with new diameter to the command
                        valueString = [ ' ' num2str(varargin{k+1},...
                            formatString)];
                    case strcmpi(varargin{k},'address')
                        address = varargin{k+1};
                    otherwise
                        error(['Property-Value pair ' num2str(k) ...
                            ' is not a valid property for diameter.\n']);
                end
            end
            
            commandString = [commandString valueString];
            
            % If the pump number is specified, make sure to pass that along
            % to the interface command.
            if ~isempty(address)
                pumpOutput = obj.interface(commandString,address);
            else
                pumpOutput = obj.interface(commandString);
            end
        end
        
        % Method for parsing output strings.
        function parseOutput(obj)
        end
        
        % Method for communicating with the pump.
        function readString = interface(obj,writeString,varargin)
            % Add the address, if necessary.
            if nargin > 2 && isnumeric(varargin{1}) && ...
                    isequal(size(varargin{1}),ones(1,2))
                % Set the number between 0 and 99 to a string with two 
                % digits.
                numString = num2str(mod(round(varargin{1}),100),'%02d');

                % Concatenate address with write string.
                writeString = [numString writeString];
            end
            
            % Print the command.
            fprintf(obj.serialHandle,writeString);
            
            % Wait for bytes to appear at the port.
            pause(obj.serialWaitTime);

            % Read the bytes at the port.
            readString = fscanf(obj.serialHandle,'%s',...
                get(obj.serialHandle,'BytesAvailable'));
        end
    end
end