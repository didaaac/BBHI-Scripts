function  [total_stimulus, total_responses, nStart]=BBHI_flanker_parser()
   %parses .log from the BBHI flanker .log file. Outpus three .csv files: 
   %one for stimulus and responses, and a summary .csv
   
   %Tuesday 8 May 2018. Universitat de Barcelona (UB). D?dac Maci? Bros. 

   %Loads .log file
   [LOGFILE,path] = uigetfile('*.log', 'Pick a .log flanker file');
   [dumb name ext]=fileparts(LOGFILE); 
   taula = table2cell(readtable([path LOGFILE], 'FileType','text'));
   disp('WAIT...');

    %starts looping from trial to trial
    firstStart=findFirstTarget(taula,1);
    
    nStart=firstStart;
    nTrial=1;
    total_stimulus=[];
    total_responses=[];
    while (nStart<size(taula,1)-1)
        [stimulus, response, nStart]=processTrial(taula, nStart);
        total_stimulus=[total_stimulus stimulus];
        total_responses=[total_responses response];
        nTrial=nTrial+1;
        
    end
    
    %writes out on .csv
    TStim = struct2table(total_stimulus);
    writetable(TStim, [path 'stim_' name '.csv']);
    TRes = struct2table(total_responses);
    writetable(TRes,[path 'res_' name '.csv']);
    
    
    %Example of summary stats---------------------    
    nTrials=size(TStim, 1)
    s.Name=get_name_of_subject(taula, firstStart);
    s.Hits_pct=round(length(find(strcmp(table2array(TStim(:,3)),'hit')))/nTrials*100,2)
    s.Incorrects_pct=round(length(find(strcmp(table2array(TStim(:,3)),'incorrect')))/nTrials*100,2)
    s.Misses_pct=round(length(find(strcmp(table2array(TStim(:,3)),'missed')))/nTrials*100,2)
    
    s.Repetitions=length(find(table2array(TRes(:,4))>1)) 
    
    indexCon=find(table2array(TStim(:,2))==11 | table2array(TStim(:,2))==12);
    RT=table2array(TRes(:,3));
    s.Mean_RT_ms=round(mean(RT),1);
    s.StD_RT_ms=round(std(RT),1);
    s.Skew_RT=round(skewness(RT),2);
    
    betas= ([ones(length(RT),1) (1:length(RT))'*2.5]\RT);
    s.Beta_RT_ms_min=round(betas(2)*60,2); 
    
    indexCon=find(table2array(TRes(:,2))==111 | table2array(TRes(:,2))==112 | table2array(TRes(:,2))==211 | table2array(TRes(:,2))==212);
    indexInc=find(~(table2array(TRes(:,2))==111 | table2array(TRes(:,2))==112 | table2array(TRes(:,2))==211 | table2array(TRes(:,2))==212));
    s.Mean_Con_RT_ms=round(mean(RT(indexCon)),1);
    s.StD_Con_RT_ms=round(std(RT(indexCon)),1);
    s.Mean_Inc_RT_ms=round(mean(RT(indexInc)),1);
    s.StD_Inc_RT_ms=round(std(RT(indexInc)),1);
    
     TS = struct2table(s);
     writetable(TS,[path 'summary_' name '.csv']);
    
end

function [stimulus, response, nEnding]=processTrial(taula, nStart);
    PP=nStart;
    response='';
    
    dataStimulus=strsplit(taula{PP,1},'\t');
    dataStimulusISI=strsplit(taula{PP+1,1},'\t');
   
    stimulus.trialNum=str2num(dataStimulusISI{8});
    stimulus.type=str2num(dataStimulus{4});
    stimulus.hit='missed'; 
    stimulus.compatible=dataStimulusISI{12};
    stimulus.time=str2num(dataStimulus{6})/10;
    stimulus.isi=str2num(dataStimulusISI{13});
    stimulus.bloc=[dataStimulusISI{6} '_' dataStimulusISI{7}];
    stimulus.responses='';
    stimulus.numResponses=[];
    stimulus.time=str2num(dataStimulus{6})/10;


    
    PP=PP+1;
    
    nResponses=0;
    while (PP<size(taula,1))
        PP=PP+1; %adds 2 because there's target+ISI +...
        data=strsplit(taula{PP,1},'\t');
        dataResponseISI=strsplit(taula{PP-1,1},'\t');
        
        if (length(data)>4)&&(strcmp(data(3), 'Response'))
            nResponses=nResponses+1;   
            response(nResponses).trialNum=str2num(dataStimulusISI{8});
            response(nResponses).type=str2num(data{4});
            response(nResponses).RT= round(str2num(data{5})-stimulus.time*10)/10;                
            response(nResponses).repeated=nResponses;
            response(nResponses).time=str2num(data{5})/10;
            response(nResponses).bloc=[dataStimulusISI{6} '_' dataStimulusISI{7}];
            
            %registers stimulus associated response            
            if (nResponses==1)
                if (data{4}(1))== dataStimulus{4}(2)
                                    stimulus.hit='hit';
                else 
                                    stimulus.hit='incorrect';
                end
            end 
            
        elseif (length(data)>4)&&any([(strcmp(data(5), 'Target')) (strcmp(data(5), 'rest'))])             
            stimulus.numResponses=length(response);
            allResponses='';
            for r=response
                allResponses=[allResponses num2str(r.type) ';'];
            end
            if strcmp(allResponses,'') allResponses='none'; end;
            stimulus.responses=allResponses;
            
            
            %find next target
            if (strcmp(data(5), 'rest'))
                PP=findFirstTarget(taula, PP)+1;
            end
            break
        end
        
    end
    nEnding=PP-1;      
end


%finds onset of logfile
function nStart=findFirstTarget(taula, PP)
nReadyGo=0;
while (PP<size(taula,1))
    data=strsplit(taula{PP,1},'\t');
    if (length(data)>4)&&(strcmp(data(5), 'Target')) 
        break
    end
  PP=PP+1;
end
  nStart=PP-1;
end

function subject_name=get_name_of_subject(taula, nStart)
    initial_info=strsplit(taula{nStart-1,1},'\t');
    subject_name=initial_info(1);
end