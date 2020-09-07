%% Define target groups

NumSimUsers=800;

for n=1:NumSimUsers
    if ismissing(Users{n}.VehicleUtilisation)
        Users{n}.VehicleUtilisation="undefined";
    end
    if ismissing(Users{n}.NumUsers)
        Users{n}.NumUsers="undefined";
    end
end

% Targets=["small"; "medium"; "large"; "transporter"];
Targets=["one user"; "only one user"; "several users"; "undefined"];
Targets=["company car"; "fleet vehicle"; "undefined"];
TargetGroups=cell(length(Targets),1);
for n=1:NumSimUsers
    TargetNum=strcmp(Users{n}.VehicleUtilisation,Targets);
    TargetGroups{TargetNum}=[TargetGroups{TargetNum} n];
end
NumExistingTargets=sum(cellfun('length', TargetGroups)>0);
ExistingTargets=find(cellfun('length', TargetGroups)>0)';

DataTable=table(Targets(ExistingTargets));
Location=["Home"; "Other"];


%% Energy charged per week

ChargeProcesses=cell(length(Targets),2);
ChargeProcessesPerWeek=cell(length(Targets),2);
for k=ExistingTargets
    for n=TargetGroups{k}
        Users{n}.ChargeProcessesHomeBase=sum(Users{n}.LogbookBase(2:end,5)>0 & Users{n}.LogbookBase(1:end-1,5)==0);
        Users{n}.ChargeProcessesOtherBase=sum(Users{n}.LogbookBase(2:end,6)>0 & Users{n}.LogbookBase(1:end-1,6)==0);
        ChargeProcesses{k,1}(n)=Users{n}.ChargeProcessesHomeBase;
        ChargeProcesses{k,2}(n)=Users{n}.ChargeProcessesOtherBase;
    end
    ChargeProcessesPerWeek{k,1}=sum(ChargeProcesses{k,1})/days(DateEnd-DateStart)*7/length(TargetGroups{k});
    ChargeProcessesPerWeek{k,2}=sum(ChargeProcesses{k,2})/days(DateEnd-DateStart)*7/length(TargetGroups{k});
end
ChargeProcessesPerWeek=ChargeProcessesPerWeek(ExistingTargets,:);
DataTable.ChargingPorcessesPerWeek=round(cell2mat(ChargeProcessesPerWeek)*100)/100;
disp(strcat("The users charge in average ", num2str(mean(cell2mat(ChargeProcessesPerWeek(:,1)))), " times per week at home and ", num2str(mean(cell2mat(ChargeProcessesPerWeek(:,2))))," times per week at ohter locations"))

%% Energy charged per charging process
tic
EnergyPerChargingProcess=cell(length(Targets),2);
for k=ExistingTargets
    EnergyPerChargingProcess{k,1}=-ones(NumSimUsers*1000,1);
    EnergyPerChargingProcess{k,2}=-ones(NumSimUsers*1000,1);
    for col=5:6
        counter=1;
        for n=TargetGroups{k}
            ChargingBlocks=[find(Users{n}.LogbookBase(2:end,col)>0 & Users{n}.LogbookBase(1:end-1,col)==0)+1, find(Users{n}.LogbookBase(1:end-1,col)>0 & Users{n}.LogbookBase(2:end,col)==0)];
            for h=1:size(ChargingBlocks,1)
                EnergyPerChargingProcess{k,col-4}(counter)=sum(Users{n}.LogbookBase(ChargingBlocks(h,1):ChargingBlocks(h,2),col));
                counter=counter+1;
            end
        end
        EnergyPerChargingProcess{k,col-4}=EnergyPerChargingProcess{k,col-4}(EnergyPerChargingProcess{k,col-4}~=-1);
    end
end

toc
EnergyPerChargingProcess=EnergyPerChargingProcess(ExistingTargets,:);
close(figure(10))
figure(10)
for col=1:2
    subplot(2,1,col)
    hold on
    [counts, centers]=hist(cat(1, EnergyPerChargingProcess{:,col})/1000, 0:4:100);
    plot(centers, counts./sum(counts))
    for k=1:NumExistingTargets
        [counts, centers]=hist(EnergyPerChargingProcess{k, col}/1000, 0:4:100);
        plot(centers, counts./sum(counts))
    end
    title(strcat("Energy per charging event in kWh ", Location(col)))
    legend([" All"; Targets(ExistingTargets)])
end

disp(strcat("In average per charging event, ", num2str(mean(cell2mat(EnergyPerChargingProcess(:,1))/1000)), " kWh were charged at home and ", num2str(mean(cell2mat(EnergyPerChargingProcess(:,2))/1000)), " at other places"))

DataTable.EnergyPerChargingProcess=round(cellfun(@mean,EnergyPerChargingProcess)/1000*100)/100;

%% Energy charged per User

EnergyCharged=cell(length(Targets),2);
for k=ExistingTargets
    for n=TargetGroups{k}
        EnergyCharged{k,1}(end+1)=sum(Users{n}.LogbookBase(1:end,5),1);
        EnergyCharged{k,2}(end+1)=sum(Users{n}.LogbookBase(1:end,6),1);
    end
end
EnergyCharged=EnergyCharged(ExistingTargets,:);
EnergyChargedPerDayPerVehicle=cellfun(@sum,EnergyCharged)/days(DateEnd-DateStart)/1000./cellfun(@length, TargetGroups(ExistingTargets));
HomeChargingQuote=sum(EnergyChargedPerDayPerVehicle(:,1))/sum(EnergyChargedPerDayPerVehicle,'all');
disp(strcat("The users charged in average ", num2str(sum(cellfun(@sum, EnergyCharged), 'all')/days(DateEnd-DateStart)/1000/NumSimUsers), " kWh per day"))
disp(strcat(num2str(HomeChargingQuote*100), " % of all charging events took place at home"))
% DataTable.EnergyChargedPerDay=

%% Arrival and Connection time at charging point

ConnectionTime=cell(length(Targets),2);
ArrivalTimes=cell(length(Targets),2);
for k=ExistingTargets
    ConnectionTime{k,1}=[];
    ConnectionTime{k,2}=[];
    ArrivalTimes{k,1}=NaT(0,0, 'TimeZone', 'Africa/Tunis');
    ArrivalTimes{k,2}=NaT(0,0, 'TimeZone', 'Africa/Tunis');
    for n=TargetGroups{k}
        ConnectionBlocksHome=[find(ismember(Users{n}.LogbookBase(1:end,1),4:5) & ~ismember([0;Users{n}.LogbookBase(1:end-1,1)],4:5)), find(ismember(Users{n}.LogbookBase(1:end,1),4:5) & ~ismember([Users{n}.LogbookBase(2:end,1);0],4:5))];
        ConnectionBlocksOther=[find(ismember(Users{n}.LogbookBase(1:end,1),6) & ~ismember([0;Users{n}.LogbookBase(1:end-1,1)],6)), find(ismember(Users{n}.LogbookBase(1:end,1),6) & ~ismember([Users{n}.LogbookBase(2:end,1);0],6))];
        ConnectionTime{k,1}=[ConnectionTime{k,1}; (ConnectionBlocksHome(:,2)-ConnectionBlocksHome(:,1)+1)*TimeStepMin];
        ConnectionTime{k,2}=[ConnectionTime{k,2}; (ConnectionBlocksOther(:,2)-ConnectionBlocksOther(:,1)+1)*TimeStepMin];
        ArrivalTimes{k,1}=[ArrivalTimes{k,1}; datetime(ones(length(ConnectionBlocksHome),1),ones(length(ConnectionBlocksHome),1),ones(length(ConnectionBlocksHome),1), hour(TimeVec(ConnectionBlocksHome(:,1))), minute((TimeVec(ConnectionBlocksHome(:,1)))),zeros(length(ConnectionBlocksHome),1), 'TimeZone', 'Africa/Tunis')];
        ArrivalTimes{k,2}=[ArrivalTimes{k,2}; datetime(ones(length(ConnectionBlocksOther),1),ones(length(ConnectionBlocksOther),1),ones(length(ConnectionBlocksOther),1), hour(TimeVec(ConnectionBlocksOther(:,1))), minute((TimeVec(ConnectionBlocksOther(:,1)))),zeros(length(ConnectionBlocksOther),1), 'TimeZone', 'Africa/Tunis')];
    end
end
ConnectionTime=ConnectionTime(ExistingTargets,:);
ArrivalTimes=ArrivalTimes(ExistingTargets,:);

close(figure(11))
figure(11)
for col=1:2
    subplot(2,1,col)
    hold on
    [counts, centers]=hist(cat(1, ConnectionTime{:,col}), (0:2:48)*60);
    plot(centers/60, counts./sum(counts))
    for k=1:NumExistingTargets
        [counts, centers]=hist(ConnectionTime{k,col}, (0:2:48)*60);
        plot(centers/60, counts./sum(counts))
    end
    title(strcat("Connection to charging point duration at ", Location(col)))
    legend([" All"; Targets(ExistingTargets)])
end
    
    
close(figure(12))
figure(12)
for col=1:2
    subplot(2,1,col)
    hold on
    [counts, edges]=histcounts(cat(1, ArrivalTimes{:,col}), datetime(1,1,1,0,0,0, 'TimeZone', 'Africa/Tunis'):hours(1):datetime(1,1,2,0,0,0, 'TimeZone', 'Africa/Tunis'));
    centers=edges(1:end-1)+(edges(2)-edges(1))/2;
    plot(centers, counts./sum(counts))
    [nrows,~] = cellfun(@size, ArrivalTimes(:,col));
    for k=find(nrows>0)'
        [counts, edges]=histcounts(ArrivalTimes{k,col}, datetime(1,1,1,0,0,0, 'TimeZone', 'Africa/Tunis'):hours(1):datetime(1,1,2,0,0,0, 'TimeZone', 'Africa/Tunis'));
        centers=edges(1:end-1)+(edges(2)-edges(1))/2;
        plot(centers, counts./sum(counts))
    end
    xticks(datetime(1,1,1,0,0,0, 'TimeZone', 'Africa/Tunis'):hours(4):datetime(1,1,2,0,0,0, 'TimeZone', 'Africa/Tunis'))
    xticklabels(datestr(datetime(1,1,1,0,0,0, 'TimeZone', 'Africa/Tunis'):hours(4):datetime(1,1,2,0,0,0, 'TimeZone', 'Africa/Tunis'), "HH:MM"))
    title(strcat("Arrival time at charging point at ", Location(col)))
    legend([" All"; Targets(nrows>0)])
end


%% Mileage

MileageYearKm=0;
for n=1:NumSimUsers
    MileageYearKm=MileageYearKm+Users{n}.AverageMileageYear_km;
end
MileageYearKm=MileageYearKm/NumSimUsers;
disp(strcat("The users drove in average ", num2str(MileageYearKm), " km per year"))

%% Coverage of VehicleNumbers

VehicleNums=[];
for n=1:NumSimUsers
    VehicleNums=[VehicleNums; Users{n}.VehicleNum];
end
close(figure(13))
figure(13)
histogram(VehicleNums, length(Vehicles))

%% Empty Batteries

EmptyBattery=0;
for n=1:NumSimUsers
    EmptyBattery(n)=sum(Users{n}.LogbookBase(2:end,7)<=0 & Users{n}.LogbookBase(1:end-1,7)>0);
end
disp(strcat(num2str(sum(EmptyBattery>0)), " users experienced empty battery"))

    