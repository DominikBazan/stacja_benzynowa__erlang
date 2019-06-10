%  stacja.erl

-module(stacja).

-export([
	kasjer/0,
	kasjerLoop/1,
	dystrybutor/0,
	dystrybutorLoop1/1,
	dystrybutorLoop2/2,
	klient/3,
	klientLoop/4,
	klientLoop2/4,
	nowiKlienci/3,
	kierownikKolejki/2,
	main/0	]).

% nowa kasa
kasjer()->
	% inicjalicacja
	CzasPlacenia = 3000,
	kasjerLoop(CzasPlacenia).

% nasluchiwanie chetnych do placenia (osobno) zeby nie powtarzac inicjalizacji
kasjerLoop(CzasPlacenia)->
  receive
		{KierownikKolejki,Klient,chceZaplacic,Kolor}->
			KierownikKolejki!{self(),zajety},
			kolor(lists:flatten(io_lib:format("Klient ~p: Place (przy kasie: ~p)...",[Klient,self()])),Kolor),
			timer:sleep(CzasPlacenia),
			Klient!{self(),koniecPlacenia},
			KierownikKolejki!{self(),zwolniony},
			kolor(lists:flatten(io_lib:format("Klient ~p: Zwalniam kase ~p...",[Klient,self()])),Kolor),
			kasjerLoop(CzasPlacenia)
	end.

kierownikKolejki(ListaWolnychStanowisk,Kolejka)->	
	receive
		{Stanowisko,zajety}->
			kierownikKolejki(lists:delete(Stanowisko,ListaWolnychStanowisk),Kolejka);	
		{Stanowisko,zwolniony}->
			NowaListaWolnychStanowisk = lists:append([Stanowisko],ListaWolnychStanowisk),
			case Kolejka of
				[] ->
					kierownikKolejki(NowaListaWolnychStanowisk,Kolejka);
				_ ->
					PierwszyKlientZKolejki = lists:nth(length(Kolejka), Kolejka),
					PierwszyKlientZKolejki ! {lists:nth(1,NowaListaWolnychStanowisk),wolny},
					kierownikKolejki(NowaListaWolnychStanowisk,lists:droplast(Kolejka))
			end;
		{Klient,dodajDoKolejki}->
			NowaKolejka = lists:append([Klient],Kolejka),
			case ListaWolnychStanowisk of
				[] ->
					kierownikKolejki(ListaWolnychStanowisk,NowaKolejka);
				_ ->
					PierwszyKlientZKolejki = lists:nth(length(NowaKolejka), NowaKolejka),
					PierwszyKlientZKolejki ! {lists:nth(1,ListaWolnychStanowisk),wolny},
					kierownikKolejki(ListaWolnychStanowisk,lists:droplast(NowaKolejka))
			end
	end.
	
% nowy dystrybutor
dystrybutor()->
	% inicjalicacja
	CzasTankowania = 2000,
	dystrybutorLoop1(CzasTankowania).

% nasluchiwanie chetnych do tankowania (osobno) zeby nie powtarzac inicjalizacji
dystrybutorLoop1(CzasTankowania)->
	receive
		{KierownikKolejki,Klient,chceTankowac,Kolor}->
			KierownikKolejki ! {self(),zajety},
			kolor(lists:flatten(io_lib:format("Klient ~p: Tankuje (przy ~p)...",[Klient,self()])),Kolor),
			timer:sleep(CzasTankowania),
			Klient!{self(),koniecTankowania},
			dystrybutorLoop2(CzasTankowania,KierownikKolejki)
	end.

% czy klient wrocil z kasy
dystrybutorLoop2(CzasTankowania,KierownikKolejki)->
	receive
		{_,zwalniamDystrybutor}->
			KierownikKolejki ! {self(),zwolniony},
			dystrybutorLoop1(CzasTankowania)
	end.

% nowy klient
klient(Dystrybutory,Kasjerzy,Kolor)->
	% inicjalicacja
	CzasPrzejsciaMiedzySamochodemAKasa = 3000,
	Dystrybutory!{self(),dodajDoKolejki},
	kolor(lists:flatten(io_lib:format("Klient ~p: Kolejka do tankowania...",[self()])),Kolor),
	receive
	{Dystrybutor,wolny}->
		Dystrybutor!{Dystrybutory,self(),chceTankowac,Kolor},
		klientLoop(CzasPrzejsciaMiedzySamochodemAKasa,Kasjerzy,Dystrybutor,Kolor)
	end.

% nasluchiwanie klienta (osobno) zeby nie powtarzac inicjalizacji
klientLoop(CzasPrzejsciaMiedzySamochodemAKasa,Kasjerzy,Dystrybutor,Kolor)->	
	receive
		{Dystrybutor,koniecTankowania}->
			kolor(lists:flatten(io_lib:format("Klient ~p: Ide do kasy...",[self()])),Kolor),
			timer:sleep(CzasPrzejsciaMiedzySamochodemAKasa),
			kolor(lists:flatten(io_lib:format("Klient ~p: Kolejka do kasy...",[self()])),Kolor),
			Kasjerzy!{self(),dodajDoKolejki},
			receive
				{Kasjer,wolny}->
					Kasjer!{Kasjerzy,self(),chceZaplacic,Kolor},
					klientLoop2(CzasPrzejsciaMiedzySamochodemAKasa,Kasjer,Dystrybutor,Kolor)
			end
	end.

klientLoop2(CzasPrzejsciaMiedzySamochodemAKasa,Kasjer,Dystrybutor,Kolor)->
	receive
		{Kasjer,koniecPlacenia}->
			kolor(lists:flatten(io_lib:format("Klient ~p: Wracam do samochodu...",[self()])),Kolor),
			timer:sleep(CzasPrzejsciaMiedzySamochodemAKasa),
			Dystrybutor!{self(),zwalniamDystrybutor},
			kolor(lists:flatten(io_lib:format("Klient ~p: Zwalniam dystrybutor ~p. (klient odjezdza)",[self(),Dystrybutor])),Kolor)
	end.

% torzenie nowych klientow
nowiKlienci(Dystrybutory,Kasjerzy,[H|T])->
	CzasPomiedzyNowymiKlientami = 5, 
	spawn(stacja,klient,[Dystrybutory,Kasjerzy,H]),
	timer:sleep(rand:uniform(CzasPomiedzyNowymiKlientami)*1000),
	nowiKlienci(Dystrybutory,Kasjerzy,T++[H]).

% czyszczenie okna
clearScreen()-> io:format(os:cmd("clear")).

% funkcja wypisujaca dana tresc w kolorze
kolor(S0, Kolor)-> io:fwrite("~s~s\e[0m~n",[Kolor,S0]).

% MAIN
main()->
	clearScreen(),
	ListaKolorow = ["\033[31m","\e[92m","\e[93m","\e[94m","\e[95m","\e[96m","\e[34m","\e[35m","\e[36m"],

	Kasjer1 = spawn(stacja,kasjer,[]),
	Kasjer2 = spawn(stacja,kasjer,[]),
	Dystrybutor1 = spawn(stacja,dystrybutor,[]),
	Dystrybutor2 = spawn(stacja,dystrybutor,[]),
	Dystrybutor3 = spawn(stacja,dystrybutor,[]),
	ListaDystrybutorow = [Dystrybutor1,Dystrybutor2,Dystrybutor3],
	ListaKasjerow = [Kasjer1,Kasjer2],
	Dystrybutory = spawn(stacja,kierownikKolejki,[ListaDystrybutorow,[]]),
	Kasjerzy = spawn(stacja,kierownikKolejki,[ListaKasjerow,[]]),
	nowiKlienci(Dystrybutory,Kasjerzy,ListaKolorow).
	
