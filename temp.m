NumUsers=1;
for y=2:100
    UserNum=y:y+NumUsers-1;
    InitialisePreAlgo;
    PreAlgo;
end
    


% lob=1;
% upb=length(Users)-1;
% 
% while abs(lob-upb)>1
%     NumUsers=ceil((upb+lob)/2);
%     UserNum=2:NumUsers+1;
%     try
%         InitialisePreAlgo
%         PreAlgo;
%         lob=NumUsers;
%     catch
%         upb=NumUsers;
%     end
% end
% UserNum=NumUsers;
% NumUsers=1;