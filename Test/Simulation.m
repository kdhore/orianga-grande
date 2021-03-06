function [results, proc_plants, storage] = Simulation(OJgameobj, decisions, year, proc_plant_old, ROJ_temp,tankersAvailable)
% Take inventory and other information from OJGameobj and initilize
% facilities
storage2market = load('Distance Data/storage2market_dist.mat');
s2m = genvarname('storage2market_dist');
grove2processing_storage = load('Distance Data/grove2processing_storage.mat');
g2ps = genvarname('grove2processing_storage_dist');
grove2processing_storage = grove2processing_storage.(g2ps);
grove2processing_storage = cell2mat(grove2processing_storage);
grove2processing_storage = [grove2processing_storage, grove2processing_storage(:,1), grove2processing_storage(:,1)];  
plant2storage = load('Distance Data/plant2storage_dist.mat');
p2s = genvarname('processing2storage_dist');
plant2storage = plant2storage.(p2s);
plant2storage = cell2mat(plant2storage);
demand_city_ORA = load('Demand Data/demand_city_ORA.mat');
dc_ora = genvarname('ORA_means_by_city');
demand_city_ORA = demand_city_ORA.(dc_ora);
demand_city_POJ = load('Demand Data/demand_city_POJ.mat');
dc_poj = genvarname('POJ_means_by_city');
demand_city_POJ = demand_city_POJ.(dc_poj);
demand_city_ROJ = load('Demand Data/demand_city_ROJ.mat');
dc_roj = genvarname('ROJ_means_by_city');
demand_city_ROJ = demand_city_ROJ.(dc_roj);
demand_city_FCOJ = load('Demand Data/demand_city_FCOJ.mat');
dc_fcoj = genvarname('FCOJ_means_by_city');
demand_city_FCOJ = demand_city_FCOJ.(dc_fcoj);


% Processing plants
plants_open = find(OJgameobj.proc_plant_cap);
proc_plants = cell(10,1);
for i = 1:10
    if year > 1
     inventory = [OJgameobj.proc_plant_inv(i).ORA];
     proc_plants{i} = ProcessingPlant(i,OJgameobj.proc_plant_cap(i),decisions.manufac_proc_plant_dec(1,i), 0, inventory,  2000, 1000, OJgameobj.tank_cars_num(i), 10, length(find(OJgameobj.storage_cap)), proc_plant_old{i}.shippingSchedule);
    else
     inventory = [OJgameobj.proc_plant_inv(i).ORA];
     shippingSchedule = cell(1,6);
     for j = 1:6
         shippingSchedule{j} = proc_plant_old{i,j};
     end
     tankers = 0;
     if tankersAvailable(i) < OJgameobj.tank_cars_num(i)
         tankers = tankersAvailable(i);
     else
         tankers = OJgameobj.tank_cars_num(i);
     end
     proc_plants{i} = ProcessingPlant(i,OJgameobj.proc_plant_cap(i),decisions.manufac_proc_plant_dec(1,i), 0, inventory,  2000, 1000, tankers, 10, length(find(OJgameobj.storage_cap)), shippingSchedule);   
    end
end

% Storage facilities
storage_open = find(OJgameobj.storage_cap);
storage = cell(length(storage_open),1);
  
for i = 1:length(storage_open)
    storage{i} = storageFacility(OJgameobj.storage_cap(storage_open(i)),OJgameobj.storage_inv(storage_open(i)),650,60,decisions.reconst_storage_dec(storage_open(i),:),storage_open(i),length(plants_open), ROJ_temp{storage_open(i)});
end

cities_match_storage = matchCitiestoStorage(storage_open, storage2market.(s2m));
       
% Draw grove prices matrix, fx grove => US$ prices, and use actual
% quantity purchased and the purchasing cost
    %grove_spot = grovePrices(); %Need to write function
    %fx = foreignEx(); % Need to write function
    %adj_BRASPA_USPrice = grove_spot(5:6,:).*fx;
    %adj_USP = [grove_spot(1:4,:); adj_BRASPA_USPrice];
    adj_USP = genPrices();
    act_quant_mult = zeros(6,12);
    for h = 1:6
        mult_1 = decisions.quant_mult_dec(h,1);
        price_1 = decisions.quant_mult_dec(h,2);
        mult_2 = decisions.quant_mult_dec(h,3);
        price_2 = decisions.quant_mult_dec(h,4);
        mult_3 = decisions.quant_mult_dec(h,5);
        price_3 = decisions.quant_mult_dec(h,6);
        for j = 1:12
            if adj_USP(h,j) <= price_1
                act_quant_mult(h,j) = mult_1;
            elseif adj_USP(h,j) <= price_2;
                act_quant_mult(h,j) = mult_2;
            elseif adj_USP(h,j) <= price_3;
                act_quant_mult(h,j) = mult_3;
            else
                act_quant_mult(h,j) = 0;
            end
        end
    end
 quant_purch = decisions.purchase_spotmkt_dec.*act_quant_mult;
 % THIS MAY NOT ALWAYS BE WHAT WE EXPECT - if there is a hurricane or
 % something in one of the groves, we may purchase less than we requested
 % bc not enough is available
 
 spot_ora_weekly = zeros(6, 48);
 for i = 1:12  
     j = 4*(i-1)+1;
     spot_ora_weekly(:,j:j+3) = repmat(quant_purch(:,i),1,4);
 end
 price_weekly_lb = zeros(6,48);
 for i = 1:12  
     j = 4*(i-1)+1;
     price_weekly_lb(:,j:j+3) = repmat(adj_USP(:,i),1,4);
 end
 price_weekly_ton = price_weekly_lb*2000;
     
 purch_cost_weekly = spot_ora_weekly.*price_weekly_ton;
 ORA_purch_cost = sum(sum(purch_cost_weekly));
 
 % Calculate the futures arriving and cost
 ora_futures = 0;
 fcoj_futures = 0;
 futures_cost_ORA =0;
 futures_cost_FCOJ = 0;
 for i = 1:5
     ora_futures = ora_futures + OJgameobj.ora_futures_current(2*(i-1)+2);
     fcoj_futures = fcoj_futures + OJgameobj.fcoj_futures_current(2*(i-1)+2);
     futures_cost_ORA = futures_cost_ORA + 2000*OJgameobj.ora_futures_current(2*(i-1)+1)*OJgameobj.ora_futures_current(2*(i-1)+2);
     futures_cost_FCOJ = futures_cost_FCOJ + 2000*OJgameobj.fcoj_futures_current(2*(i-1)+1)*OJgameobj.fcoj_futures_current(2*(i-1)+2);
 end

 % Number of ORA/FCOJ futures arriving each month at the florida grove
 futures_arr_ORA = ora_futures.*(decisions.arr_future_dec_ORA*0.01);
 futures_arr_FCOJ = fcoj_futures.*(decisions.arr_future_dec_FCOJ*0.01);
 
 % Cost of shipping FCOJ futures
 cost_shipping_FCOJ_futures = zeros(12,length(storage));
 for i = 1:length(storage)
    % Fraction of total FCOJ arriving at florida grove that are being shipped to storage facitlity (storage_open(i)) 
    fraction_shipped = decisions.futures_ship_dec(storage_open(i));
    monthly_amt_shipped = futures_arr_FCOJ*fraction_shipped*.01;
    cost_per_ton = 0.22*grove2processing_storage(10 + storage_open(i),1);
    %cost_per_ton = findGrove2PlantOrStorageDist('FLA', char(storageNamesInUse(storage_open(i))))*0.22; % I hope this function has been called correctly (MICHELLE) FUCK YOU KARTHIK
    cost_shipping_FCOJ_futures(:,i) = monthly_amt_shipped'.*cost_per_ton; 
 end
 
 transCostfromGroves_FCOJ = sum(sum(cost_shipping_FCOJ_futures));
 
  % Transporation of oranges shipped from groves weekly
 futures_per_week_ORA = zeros(1,48);
 for i = 1:12
     j = 4*(i-1)+1;
     futures_per_week_ORA(1,j:j+3) = repmat(futures_arr_ORA(i)/4,1,4);
 end
 total_ora_shipped = spot_ora_weekly + vertcat(futures_per_week_ORA, zeros(5,48));
% Calculate costs of ORA shipments from groves to PP and Storage
numPlantsStorage = length(plants_open)+length(storage_open);
transCost_fromGroves = zeros(numPlantsStorage, 6);
plantsAndStorage = [plants_open; storage_open];
for i = 1:6 % loop over groves
    for j = 1:numPlantsStorage
        if (j <= length(plants_open))
            PorSindex = plantsAndStorage(j);
        else
            PorSindex = plantsAndStorage(j)+10;
        end
        transCost_fromGroves(j,i) = grove2processing_storage(PorSindex, i)*0.22*sum(total_ora_shipped(i,:))*decisions.ship_grove_dec(i,j)*0.01;
    end
end

transCostfromGroves_ORA = sum(sum(transCost_fromGroves));
    
 % Iterate over all the months
 POJ_man = zeros(length(plants_open),48); 
 FCOJ_man = zeros(length(plants_open),48); 
 ROJ_man = zeros(length(storage_open),48); 
 soldORA = zeros(length(storage_open),48);
 soldPOJ = zeros(length(storage_open),48);
 soldROJ = zeros(length(storage_open),48);
 soldFCOJ = zeros(length(storage_open),48);
 toss_outStorORA = zeros(length(storage_open),48);
 toss_outStorPOJ = zeros(length(storage_open),48);
 toss_outStorROJ = zeros(length(storage_open),48);
 toss_outStorFCOJ = zeros(length(storage_open),48);
 toss_outProc = zeros(length(plants_open),48); 
 rottenStorORA = zeros(length(storage_open),48);
 rottenStorPOJ = zeros(length(storage_open),48);
 rottenStorROJ = zeros(length(storage_open),48);
 rottenStorFCOJ = zeros(length(storage_open),48);
 rottenProc = zeros(length(plants_open),48);
 revReceivedORA = zeros(length(storage_open),48);
 revReceivedPOJ = zeros(length(storage_open),48);
 revReceivedROJ = zeros(length(storage_open),48);
 revReceivedFCOJ = zeros(length(storage_open),48);
 transCfromPlants_tank = cell(length(plants_open),48); 
 transCfromPlants_carrier = cell(length(plants_open),48); 
 holdCost = zeros(length(storage_open),48); 
 tankersHoldC = zeros(length(plants_open),48);
 transport2cities_cost = zeros(length(storage_open),48);
 for i = 1:48
     for j = 1:length(plants_open)
         shipped_ORA_FLA = decisions.ship_grove_dec(1,j)*0.01*total_ora_shipped(1,i);
         shipped_ORA_CAL = decisions.ship_grove_dec(2,j)*0.01*total_ora_shipped(2,i);
         shipped_ORA_TEX = decisions.ship_grove_dec(3,j)*0.01*total_ora_shipped(3,i);
         shipped_ORA_ARZ = decisions.ship_grove_dec(4,j)*0.01*total_ora_shipped(4,i);
         shipped_ORA_BRA = decisions.ship_grove_dec(5,j)*0.01*total_ora_shipped(5,i);
         shipped_ORA_SPA = decisions.ship_grove_dec(6,j)*0.01*total_ora_shipped(6,i);
         sum_shipped = shipped_ORA_FLA + shipped_ORA_CAL + shipped_ORA_TEX + shipped_ORA_ARZ + ...
                       shipped_ORA_BRA + shipped_ORA_SPA;
         breakdown = rand;
         if (breakdown < .05)
             breakdown = 1;
         else
             breakdown = 0;
         end
         proc_plants{plants_open(j)} = proc_plants{plants_open(j)}.iterateWeek(sum_shipped, decisions, breakdown, storage_open, plant2storage);
         POJ_man(j,i) = proc_plants{plants_open(j)}.poj;
         FCOJ_man(j,i) = proc_plants{plants_open(j)}.fcoj;
         tankersHoldC(j,i) = proc_plants{plants_open(j)}.tankersHoldC;
         transCfromPlants_tank{j,i} = proc_plants{plants_open(j)}.shipped_out_cost_tank;
         transCfromPlants_carrier{j,i} = proc_plants{plants_open(j)}.shipped_out_cost_carrier;
         rottenProc(j,i) = proc_plants{plants_open(j)}.rotten;
         toss_outProc(j,i) = proc_plants{plants_open(j)}.throwaway;
     end
     for j = 1:length(storage)
         shipped_ORA_FLA = decisions.ship_grove_dec(1,j+length(plants_open))*0.01*total_ora_shipped(1,i);
         shipped_ORA_CAL = decisions.ship_grove_dec(2,j+length(plants_open))*0.01*total_ora_shipped(2,i);
         shipped_ORA_TEX = decisions.ship_grove_dec(3,j+length(plants_open))*0.01*total_ora_shipped(3,i);
         shipped_ORA_ARZ = decisions.ship_grove_dec(4,j+length(plants_open))*0.01*total_ora_shipped(4,i);
         shipped_ORA_BRA = decisions.ship_grove_dec(5,j+length(plants_open))*0.01*total_ora_shipped(5,i);
         shipped_ORA_SPA = decisions.ship_grove_dec(6,j+length(plants_open))*0.01*total_ora_shipped(6,i);
         sum_shipped = shipped_ORA_FLA + shipped_ORA_CAL + shipped_ORA_TEX + shipped_ORA_ARZ + ...
                       shipped_ORA_BRA + shipped_ORA_SPA;
         fraction_shipped_futures = decisions.futures_ship_dec(storage_open(j));
         monthly_amt_futures_shipped_FCOJ = futures_arr_FCOJ*fraction_shipped_futures*.01;
         indicies = strcmp(char(storageNamesInUse(storage_open(j))),cities_match_storage(:,2));
         cities = cities_match_storage(indicies,:);
         %name = char(storageNamesInUse(storage_open(j)));
         %[ORA_demand, POJ_demand, FCOJ_demand, ROJ_demand, big_D, big_P] = drawDemand(decisions,cities,i, demand_city_ORA, demand_city_POJ, demand_city_ROJ, demand_city_FCOJ, decisions.storage_res(name), indicies); % will need to give it a price, and do this for all products
         [ORA_demand, POJ_demand, FCOJ_demand, ROJ_demand, big_D, big_P] = drawDemand(decisions,cities,i, demand_city_ORA, demand_city_POJ, demand_city_ROJ, demand_city_FCOJ);
         storage{j} = storage{j}.iterateWeek(sum_shipped, (monthly_amt_futures_shipped_FCOJ(ceil(i/4)))/4, proc_plants, big_D, big_P, i, ORA_demand, POJ_demand, FCOJ_demand, ROJ_demand, cities, storage_open(j), plants_open);
         soldORA(j,i) = storage{j}.sold(1);
         soldPOJ(j,i) = storage{j}.sold(2);
         soldROJ(j,i) = storage{j}.sold(3);
         soldFCOJ(j,i) = storage{j}.sold(4);
         toss_outStorORA(j,i) = storage{j}.cum_toss_out(1);
         toss_outStorPOJ(j,i) = storage{j}.cum_toss_out(2);
         toss_outStorROJ(j,i) = storage{j}.cum_toss_out(3);
         toss_outStorFCOJ(j,i) = storage{j}.cum_toss_out(4);
         rottenStorORA(j,i) = storage{j}.rotten(1);
         rottenStorPOJ(j,i) = storage{j}.rotten(2);
         rottenStorROJ(j,i) = storage{j}.rotten(3);
         rottenStorFCOJ(j,i) = storage{j}.rotten(4);
         excessDemand = storage{j}.excessDemand;
         ROJ_man(j,i) = storage{j}.ROJman;
         holdCost(j,i) = storage{j}.holdCost;
         revReceivedORA(j,i) = storage{j}.revReceived(1);
         revReceivedPOJ(j,i) = storage{j}.revReceived(2);
         revReceivedROJ(j,i) = storage{j}.revReceived(3);
         revReceivedFCOJ(j,i) = storage{j}.revReceived(4);
         transport2cities_cost(j,i) = storage{j}.transCost;
     end
 end
 totPOJ_man = sum(sum(POJ_man)); 
 totFCOJ_man = sum(sum(FCOJ_man)); 
 totROJ_man = sum(sum(ROJ_man)); 
 totSoldORA = sum(sum(soldORA));
 totSoldPOJ = sum(sum(soldPOJ));
 totSoldROJ = sum(sum(soldROJ));
 totSoldFCOJ = sum(sum(soldFCOJ));
 totToss_out = sum(sum(toss_outStorORA))+sum(sum(toss_outStorPOJ))+sum(sum(toss_outStorROJ))+sum(sum(toss_outStorFCOJ))+sum(sum(toss_outProc)); 
 totRottenORA = sum(sum(rottenProc))+sum(sum(rottenStorORA));
 totRottenPOJ = sum(sum(rottenStorPOJ));
 totRottenROJ = sum(sum(rottenStorROJ));
 totRottenFCOJ = sum(sum(rottenStorFCOJ));
 totRotten = totRottenORA+totRottenPOJ+totRottenROJ+totRottenFCOJ;
 totRevReceivedORA = sum(sum(revReceivedORA));
 totRevReceivedPOJ = sum(sum(revReceivedPOJ));
 totRevReceivedROJ = sum(sum(revReceivedROJ));
 totRevReceivedFCOJ = sum(sum(revReceivedFCOJ));
 totTransCfromPlants_tank_temp = zeros(length(plants_open),length(storage_open));
 for i = 1:length(plants_open)
     for k = 1:length(storage_open)
         tempSum = 0;
        for j = 1:48
             tempSum = tempSum + transCfromPlants_tank{i,j}(k);
        end
        totTransCfromPlants_tank_temp(i,k) = tempSum;
     end
 end
 totTransCfromPlants_tank = sum(sum(totTransCfromPlants_tank_temp)); 
 totTransCfromPlants_carrier_temp = zeros(length(plants_open),length(storage_open));
 for i = 1:length(plants_open)
     for k = 1:length(storage_open)
        tempSum = 0;
         for j = 1:48
             tempSum = tempSum + transCfromPlants_carrier{i,j}(k);
        end
        totTransCfromPlants_carrier_temp(i,k) = tempSum;
     end
 end
 totTransCfromPlants_carrier = sum(sum(totTransCfromPlants_carrier_temp));
 totHoldCost = sum(sum(holdCost)); 
 totTankHoldCost = sum(sum(tankersHoldC));
 totTransport2cities_cost = sum(sum(transport2cities_cost));
 pojManCost = totPOJ_man*2000;
 fcojManCost = totFCOJ_man*1000;
 reconCost = totROJ_man*650;

ORA_futures_purch = decisions.future_mark_dec_ORA(:,2);
FCOJ_futures_purch = decisions.future_mark_dec_FCOJ(:,2);
plant_cap_upgrade = 0;
plant_cap_downgrade = 0;
storage_cap_upgrade = 0;
storage_cap_downgrade = 0;
for i = 1:10
    if decisions.proc_plant_dec(i) > 0
        plant_cap_upgrade = plant_cap_upgrade + decisions.proc_plant_dec(i);
    elseif decisions.proc_plant_dec(i) < 0
        plant_cap_downgrade = plant_cap_downgrade + decisions.proc_plant_dec(i);
    end
end
for i = 1:71
    if decisions.storage_dec(i) > 0
        storage_cap_upgrade = storage_cap_upgrade + decisions.storage_dec(i);
    elseif decisions.storage_dec(i) < 0
        storage_cap_downgrade = storage_cap_downgrade + decisions.storage_dec(i);
    end
end
newtank = max(sum(decisions.tank_car_dec),0);
tanksold = -min(sum(decisions.tank_car_dec),0);

newplants = 0;
plantsold = 0;
for i = 1:length(decisions.proc_plant_dec)
    if (decisions.proc_plant_dec(i) > 0 && OJgameobj.proc_plant_cap(i) == 0)
        newplants = newplants + 1;
    elseif (decisions.proc_plant_dec(i) < 0 && OJgameobj.proc_plant_cap(i)+decisions.proc_plant_dec(i) == 0)
        plantsold = plantsold + 1;
    end
end

newstorage = 0;
storagesold = 0;
for i = 1:length(decisions.storage_dec)
    if (decisions.storage_dec(i) > 0 && OJgameobj.storage_cap(i) == 0)
        newstorage = newstorage + 1;
    elseif (decisions.storage_dec(i) < 0 && OJgameobj.storage_cap(i)+decisions.storage_dec(i) == 0)
        storagesold = storagesold + 1;
    end
end

proc_plants_new = find(OJgameobj.proc_plant_cap);
proc_plants_main = 8000000*length(proc_plants_new)+sum(2500*OJgameobj.proc_plant_cap(proc_plants_new));
costs_new_plants = newplants*12000000-plantsold*70/100*12000000;
proc_plant_cap_costs = 8000*plant_cap_upgrade+0.7*8000*plant_cap_downgrade; 
storages = find(OJgameobj.storage_cap);
storage_main = 7500000*length(storages)+sum(650*OJgameobj.storage_cap(storages)); 
costs_new_storage = newstorage*9000000-storagesold*80/100*9000000; 
storage_cap_costs = 6000*storage_cap_upgrade+0.8*6000*storage_cap_downgrade; 
tankCar_purchase_costs = newtank*100000-tanksold*60/100*100000;
    
sales = [totSoldORA;totSoldPOJ;totSoldROJ;totSoldFCOJ];
materialsAcqLos = [ora_futures; fcoj_futures; totPOJ_man; totFCOJ_man; totROJ_man; totToss_out; totRotten];
futures = [sum(ORA_futures_purch); sum(FCOJ_futures_purch)];
facilities = [plant_cap_upgrade; storage_cap_upgrade; plant_cap_downgrade; storage_cap_downgrade; newplants; newstorage; newtank; plantsold; storagesold; tanksold]; %decisions
salesRev = [totRevReceivedORA;totRevReceivedPOJ;totRevReceivedROJ;totRevReceivedFCOJ];
materialsCost = [ORA_purch_cost; futures_cost_ORA; futures_cost_FCOJ; transCostfromGroves_ORA; transCostfromGroves_FCOJ];
manCost = [pojManCost; fcojManCost; reconCost];
transCost = [totTransCfromPlants_tank; totTransCfromPlants_carrier; totHoldCost; totTransport2cities_cost];
maintainenceCost = [proc_plants_main; costs_new_plants; proc_plant_cap_costs; storage_main; costs_new_storage; storage_cap_costs; totTankHoldCost; tankCar_purchase_costs]; %decisions

totalRevenue = sum(salesRev);
totalCosts = sum(materialsCost) + sum(manCost) + sum(transCost) + sum(maintainenceCost);

results = cell(10,1);
results{1} = sales;
results{2} = materialsAcqLos;
results{3} = futures;
results{4} = facilities;
results{5} = salesRev;
results{6} = materialsCost;
results{7} = manCost;
results{8} = transCost;
results{9} = maintainenceCost;
results{10} = totalRevenue - totalCosts;

end

