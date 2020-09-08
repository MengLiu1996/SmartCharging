tic
Demo=false;
ActivateWaitbar=true;
NumSimUsers=800;
PublicChargingThreshold=uint32(15); % in %

PThreshold=1.2;
NumPredMethod=1;

k=0;
TimeOfForecast=datetime(1,1,1,08,0,0,'TimeZone','Africa/Tunis');
TimeVecDateNum=datenum(TimeVec);

if ~exist('PublicChargerDistribution', 'var')
    PathVehicleData=[Path 'Predictions' Dl 'VehicleData' Dl];
    PublicChargerDistribution=readmatrix(strcat(PathVehicleData, "PublicChargerProbability.xlsx"));
end

ChargingPower=zeros(NumSimUsers,1);
ChargingEfficiency=zeros(NumSimUsers,1);
EnergyDemandLeft=zeros(NumSimUsers,1);
close all hidden

if Demo
    ForecastIntervalInd=ForecastIntervalHours*TimeStepInd;
    DemoUser=1;
    while Users{DemoUser}.PVPlantExists==false || sum(Users{DemoUser}.LogbookSource(:,1)>2)<100
        DemoUser=DemoUser+1;
    end
end

for n=1:size(Users,1)
    Users{n}.LogbookBase=Users{n}.LogbookSource;
end

if ActivateWaitbar
    h=waitbar(0, "Simuliere Ladevorgänge");
    TotalIterations=RangeTestInd(2)-(RangeTrainInd(1)+1);
end

for TimeInd=RangeTrainInd(1)+1:RangeTestInd(2)
    
    for n=12:12%:NumSimUsers% DemoUser%size(Users,1)
        
        if (Users{n}.LogbookBase(TimeInd,1)==1 && Users{n}.LogbookBase(TimeInd-1,7)*100/Users{n}.BatterySize<PublicChargingThreshold) || (TimeInd+1<=size(Users{n}.LogbookBase,1) && Users{n}.LogbookBase(TimeInd,4)>=Users{n}.LogbookBase(TimeInd-1,7))
            
            NextHomeStop=min([length(Users{n}.LogbookBase), find(Users{n}.LogbookBase(TimeInd:end,1)==3,1)+TimeInd-1]); %[TimeIndices]
            ConsumptionTilNextHomeStop=sum(Users{n}.LogbookBase(TimeInd:NextHomeStop,4)); % [Wh]
            TripDistance=sum(Users{n}.LogbookBase(TimeInd:NextHomeStop,3)); % [Wh]

            PublicChargerPower=max((rand(1)>=PublicChargerDistribution(find(PublicChargerDistribution>TripDistance/1000,1),:)).*PublicChargerDistribution(1,:)); % [kW]
            ChargingPower(n)=min([max([Users{n}.ACChargingPowerVehicle, Users{n}.DCChargingPowerVehicle]), PublicChargerPower]); % Actual ChargingPower at public charger in [kW]
%             ChargingEfficiency(n)=PublicChargerDistribution(end,find(ChargingPower(n)<=PublicChargerDistribution(1,2:end),1)+1)*((1.01-0.91)*randn(1)+0.99);
            
            EnergyDemandLeft(n)=double(min((double(PublicChargingThreshold)+2)/100*Users{n}.BatterySize+ConsumptionTilNextHomeStop-Users{n}.LogbookBase(TimeInd-1,7), Users{n}.BatterySize-Users{n}.LogbookBase(TimeInd-1,7)));
            TimeStepIndsNeededForCharging=ceil(EnergyDemandLeft(n)/ChargingPower(n)*60/TimeStepMin); % [Wh/W]
            
            if TimeStepIndsNeededForCharging>0
                EndOfShift=[strfind(Users{n}.LogbookBase(TimeInd:end,3)',zeros(1,TimeStepIndsNeededForCharging)), 1e9]; % Find the next time, when the vehicle parks for TimeStepIndsNeededForCharging complete TimeSteps
                EndOfShift=min([length(Users{n}.LogbookBase), EndOfShift(1)+TimeInd+TimeStepIndsNeededForCharging-1-1]);
                Users{n}.LogbookBase(TimeInd:EndOfShift,:)=Users{n}.LogbookBase(TimeInd-TimeStepIndsNeededForCharging:EndOfShift-TimeStepIndsNeededForCharging,:);
                TimeStepIndsNeededForCharging=min(length(Users{n}.LogbookBase)-(TimeInd-1), TimeStepIndsNeededForCharging);
                Users{n}.LogbookBase(TimeInd:TimeInd+TimeStepIndsNeededForCharging-1,1:7)=ones(TimeStepIndsNeededForCharging,1)*[6, zeros(1,6)]; % Public charging due to low SoC
            end
        end
        
        if EnergyDemandLeft(n)>0 %Users{n}.LogbookBase(TimeInd,1)==6
            Users{n}.LogbookBase(TimeInd,6)=min([EnergyDemandLeft(n), ChargingPower(n)*TimeStepMin/60]); % Publicly charged energy during one TimeStep in [Wh]
            EnergyDemandLeft(n)=EnergyDemandLeft(n)-Users{n}.LogbookBase(TimeInd,6);
%             if Users{n}.LogbookBase(TimeInd,4)>0
%                 
%                 if Users{n}.LogbookBase(TimeInd,2)>(TimeStepMin-ChargingTime) % if charging would collide with driving, then shift driving a bit
%                     EndOfShift=find(Users{n}.LogbookBase(TimeInd:end,2)<(TimeStepMin-ChargingTime));
%                     EndOfShift=min([length(Users{n}.LogbookBase), EndOfShift(1)+TimeInd-1]);
%                     Users{n}.LogbookBase1=Users{n}.LogbookBase;
%                     for k=EndOfShift:-1:TimeInd+1
%                         Users{n}.LogbookBase(k,2)=Users{n}.LogbookBase(k-1,2)+ChargingTime-TimeStepMin;
%                         Users{n}.LogbookBase(k-1,2)=Users{n}.LogbookBase(k-1,2)-Users{n}.LogbookBase(k,2);
%                         Users{n}.LogbookBase(k,3:4)=Users{n}.LogbookBase(k,3:4)*(TimeStepMin/(TimeStepMin-ChargingTime)); % multiply the inverse of what you subtract one row below: A*(1-B/C)*x==A --> x=C/(C-B) 
%                         Users{n}.LogbookBase(k-1,3:4)=Users{n}.LogbookBase(k-1,3:4)*(1-ChargingTime/TimeStepMin);
%                         if Users{n}.LogbookBase(k,2)==TimeStepMin
%                             Users{n}.LogbookBase(k,1)=1;
%                         end
%                     end
%                     Users{n}.LogbookBase1(TimeInd+1:EndOfShift,2)=Users{n}.LogbookBase1(TimeInd+1:EndOfShift,2)+ChargingTime;
%                     Users{n}.LogbookBase1(TimeInd:EndOfShift-1,2)=Users{n}.LogbookBase1(TimeInd:EndOfShift-1,2)-ChargingTime;
%                     Users{n}.LogbookBase1(TimeInd+1:EndOfShift,3:4)=Users{n}.LogbookBase1(TimeInd+1:EndOfShift,3:4)*(TimeStepMin/(TimeStepMin-ChargingTime)); % multiply the inverse of what you subtract one row below: A*(1-B/C)*x==A --> x=C/(C-B) 
%                     Users{n}.LogbookBase1(TimeInd:EndOfShift-1,3:4)=Users{n}.LogbookBase1(TimeInd:EndOfShift-1,3:4)*(1-ChargingTime/TimeStepMin);
                    
%                 end
%             end       
        end
        
        if Users{n}.LogbookBase(TimeInd,1)==3
            
            if Users{n}.LogbookBase(TimeInd-1,1)<3
                
    %             [Users{n}]=DetermineChargingBaseScenario(Users{n}, TimeInd, TimeStep);

                if Users{n}.ChargingStrategy==1 % Always connect car to charging point if Duration of parking is higher than MinimumPluginTime
                    ParkingDuration=(find(Users{n}.LogbookBase(TimeInd:end,1)<3,1)-1)*TimeStep;
                    if ParkingDuration>Users{n}.MinimumPluginTime
                        Users{n}.LogbookBase(TimeInd,1)=4; % Plugged-in
                    else
                        Users{n}.LogbookBase(TimeInd,1)=3; % Not plugged-in
                    end

                elseif Users{n}.ChargingStrategy==2 % The probability of connection is a function of Plug-in time, SoC and the consumption within the next 24h
                    Consumption24h=uint32(sum(Users{n}.LogbookBase(TimeInd:min(TimeInd+hours(24)/TimeStep-1, size(Users{n}.LogbookBase,1)), 3))*Users{n}.Consumption/1000); % [Wh]
                    if Consumption24h>Users{n}.LogbookBase(TimeInd-1,7)
                        Users{n}.LogbookBase(TimeInd,1)=4; % Plugged-in
                    else
                        PlugInTime=(find([Users{n}.LogbookBase(TimeInd+1:end,1);0]<3,1)-1)*TimeStep;
                        P=min(1,PlugInTime/hours(2)) + min(1, (single(Users{n}.BatterySize-Users{n}.LogbookBase(TimeInd-1,7)))/single(Users{n}.BatterySize)) + min(1, single(Consumption24h)/single(Users{n}.LogbookBase(TimeInd-1,7)));
                        if P>PThreshold
                            Users{n}.LogbookBase(TimeInd,1)=4; % Plugged-in
                        else
                            Users{n}.LogbookBase(TimeInd,1)=3; % Not plugged-in
                        end
                    end
                end
            
            elseif Users{n}.LogbookBase(TimeInd-1,1)>=4
                Users{n}.LogbookBase(TimeInd,1)=4;
            end
        end
        
        Users{n}.LogbookBase(TimeInd,7)=Users{n}.LogbookBase(TimeInd-1,7)-Users{n}.LogbookBase(TimeInd,4);
        if Users{n}.LogbookBase(TimeInd,1)==4 && Users{n}.LogbookBase(TimeInd,7)<Users{n}.BatterySize
            Users{n}.LogbookBase(TimeInd,1)=5;
%             Users{n}.LogbookBase(TimeInd,5)=min(max(minutes(0), TimeStep-minutes(Users{n}.LogbookBase(TimeInd,2))-minutes(1))/hours(1)*Users{n}.ChargingPower, Users{n}.BatterySize-Users{n}.LogbookBase(TimeInd-1,7)); %[Wh]
            Users{n}.LogbookBase(TimeInd,5)=min((TimeStepMin-Users{n}.LogbookBase(TimeInd,2))*Users{n}.ACChargingPowerHomeCharging/60, Users{n}.BatterySize-Users{n}.LogbookBase(TimeInd-1,7)); %[Wh]
        end
        
        if  Users{n}.LogbookBase(TimeInd,7)<Users{n}.BatterySize && Users{n}.LogbookBase(TimeInd,1)>=5
            Users{n}.LogbookBase(TimeInd,7)=Users{n}.LogbookBase(TimeInd,7)+Users{n}.LogbookBase(TimeInd,5)+Users{n}.LogbookBase(TimeInd,6);
        end
            
    end
    
    if TimeInd==RangeTestInd(1) && Demo
        SimulationDemoInit;
    end
    if TimeInd>=RangeTestInd(1) && Demo
        SimulationDemoLoop;
    end
    
    if ActivateWaitbar && mod(TimeInd,1000)==0
        waitbar((TimeInd-RangeTrainInd(1)+1)/TotalIterations);
    end
end
if ActivateWaitbar
    close(h)
end
toc