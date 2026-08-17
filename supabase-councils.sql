-- Adopt an Area — municipalities / local government (run once in the Supabase SQL
-- editor, AFTER supabase-public-groups.sql and supabase-group-admins.sql)
--
-- What this adds
-- --------------
-- A municipality can sign in with its own kind of account and, for the district it
-- speaks for:
--   * publish a list of what residents may do WITHOUT asking anybody first,
--     what needs a phone call, and what is flat-out not allowed
--   * publish how to reach the right office for everything not on that list
--   * see the residents using the app inside its own district — and only its own
--
-- Nobody hands themselves a council account. You apply, and a site admin approves.
--
-- On the resident list and POPIA
-- ------------------------------
-- Handing a municipality a list of names, cell numbers and email addresses is
-- personal information under POPIA, so this is built to be defensible rather than
-- convenient:
--   * scoping is done here in the database, not in the browser — a council account
--     that asks for another district's residents gets an error, not data
--   * every resident may switch their contact details off (profiles.share_contact),
--     and the sign-up screen tells them who sees them. It defaults to ON, so a
--     council does see everybody unless somebody opts out
--   * every read is written to council_access_log, so who looked at what, and when,
--     is answerable
-- Before switching this on for real municipalities you still want the operator
-- side of POPIA in place: a registered Information Officer, a privacy notice, and
-- an agreement with each municipality about what they may use the list for.

-- 0) Towns table ---------------------------------------------------------------
-- The province → district → town list lives in index.html as a JS array, which the
-- database can't read. Without it here, council_residents() would have to trust the
-- browser to say which towns are in a district — and a browser can say anything.
-- So the same list is mirrored here and the scoping is done against this table.
--
-- Generated from the `provinces` array in index.html. If you add towns there, add
-- them here too.
--
-- Note: ids are name slugs, and three of them repeat across provinces —
-- 'middelburg' (Chris Hani + Nkangala), 'groblersdal' (Nkangala + Sekhukhune) and
-- 'zeerust' (Bojanala Platinum + Ngaka Modiri Molema). Hence the (id, district)
-- key. A resident of one of those three shows up for both municipalities of that
-- name, because nothing recorded about them says which one they meant.

create table if not exists public.towns (
  id       text not null,
  name     text not null,
  district text not null,
  province text not null,
  primary key (id, district)
);

alter table public.towns enable row level security;
drop policy if exists "towns are public" on public.towns;
create policy "towns are public" on public.towns for select using (true);

insert into public.towns (id, name, district, province) values
  ('east-london','East London','Buffalo City Metro','Eastern Cape'),
  ('gonubie','Gonubie','Buffalo City Metro','Eastern Cape'),
  ('mdantsane','Mdantsane','Buffalo City Metro','Eastern Cape'),
  ('qonce','Qonce','Buffalo City Metro','Eastern Cape'),
  ('zwelitsha','Zwelitsha','Buffalo City Metro','Eastern Cape'),
  ('colchester','Colchester','Nelson Mandela Bay Metro','Eastern Cape'),
  ('despatch','Despatch','Nelson Mandela Bay Metro','Eastern Cape'),
  ('gqeberha','Gqeberha','Nelson Mandela Bay Metro','Eastern Cape'),
  ('kariega','Kariega','Nelson Mandela Bay Metro','Eastern Cape'),
  ('kwanobuhle','KwaNobuhle','Nelson Mandela Bay Metro','Eastern Cape'),
  ('matatiele','Matatiele','Alfred Nzo District','Eastern Cape'),
  ('mbizana','Mbizana','Alfred Nzo District','Eastern Cape'),
  ('mount-ayliff','Mount Ayliff','Alfred Nzo District','Eastern Cape'),
  ('mount-frere','Mount Frere','Alfred Nzo District','Eastern Cape'),
  ('ntabankulu','Ntabankulu','Alfred Nzo District','Eastern Cape'),
  ('adelaide','Adelaide','Amathole District','Eastern Cape'),
  ('alice','Alice','Amathole District','Eastern Cape'),
  ('butterworth','Butterworth','Amathole District','Eastern Cape'),
  ('cathcart','Cathcart','Amathole District','Eastern Cape'),
  ('dutywa','Dutywa','Amathole District','Eastern Cape'),
  ('fort-beaufort','Fort Beaufort','Amathole District','Eastern Cape'),
  ('keiskammahoek','Keiskammahoek','Amathole District','Eastern Cape'),
  ('komga','Komga','Amathole District','Eastern Cape'),
  ('peddie','Peddie','Amathole District','Eastern Cape'),
  ('stutterheim','Stutterheim','Amathole District','Eastern Cape'),
  ('cala','Cala','Chris Hani District','Eastern Cape'),
  ('cofimvaba','Cofimvaba','Chris Hani District','Eastern Cape'),
  ('cradock','Cradock','Chris Hani District','Eastern Cape'),
  ('engcobo','Engcobo','Chris Hani District','Eastern Cape'),
  ('hofmeyr','Hofmeyr','Chris Hani District','Eastern Cape'),
  ('komani','Komani','Chris Hani District','Eastern Cape'),
  ('middelburg','Middelburg','Chris Hani District','Eastern Cape'),
  ('sterkstroom','Sterkstroom','Chris Hani District','Eastern Cape'),
  ('tarkastad','Tarkastad','Chris Hani District','Eastern Cape'),
  ('aliwal-north','Aliwal North','Joe Gqabi District','Eastern Cape'),
  ('barkly-east','Barkly East','Joe Gqabi District','Eastern Cape'),
  ('burgersdorp','Burgersdorp','Joe Gqabi District','Eastern Cape'),
  ('lady-grey','Lady Grey','Joe Gqabi District','Eastern Cape'),
  ('maclear','Maclear','Joe Gqabi District','Eastern Cape'),
  ('rhodes','Rhodes','Joe Gqabi District','Eastern Cape'),
  ('sterkspruit','Sterkspruit','Joe Gqabi District','Eastern Cape'),
  ('steynsburg','Steynsburg','Joe Gqabi District','Eastern Cape'),
  ('ugie','Ugie','Joe Gqabi District','Eastern Cape'),
  ('flagstaff','Flagstaff','OR Tambo District','Eastern Cape'),
  ('libode','Libode','OR Tambo District','Eastern Cape'),
  ('lusikisiki','Lusikisiki','OR Tambo District','Eastern Cape'),
  ('mthatha','Mthatha','OR Tambo District','Eastern Cape'),
  ('ngqeleni','Ngqeleni','OR Tambo District','Eastern Cape'),
  ('port-st-johns','Port St Johns','OR Tambo District','Eastern Cape'),
  ('qumbu','Qumbu','OR Tambo District','Eastern Cape'),
  ('tsolo','Tsolo','OR Tambo District','Eastern Cape'),
  ('aberdeen','Aberdeen','Sarah Baartman District','Eastern Cape'),
  ('addo','Addo','Sarah Baartman District','Eastern Cape'),
  ('alexandria','Alexandria','Sarah Baartman District','Eastern Cape'),
  ('alicedale','Alicedale','Sarah Baartman District','Eastern Cape'),
  ('cookhouse','Cookhouse','Sarah Baartman District','Eastern Cape'),
  ('graaff-reinet','Graaff-Reinet','Sarah Baartman District','Eastern Cape'),
  ('humansdorp','Humansdorp','Sarah Baartman District','Eastern Cape'),
  ('jansenville','Jansenville','Sarah Baartman District','Eastern Cape'),
  ('jeffreys-bay','Jeffreys Bay','Sarah Baartman District','Eastern Cape'),
  ('joubertina','Joubertina','Sarah Baartman District','Eastern Cape'),
  ('kareedouw','Kareedouw','Sarah Baartman District','Eastern Cape'),
  ('kirkwood','Kirkwood','Sarah Baartman District','Eastern Cape'),
  ('makhanda','Makhanda','Sarah Baartman District','Eastern Cape'),
  ('oyster-bay','Oyster Bay','Sarah Baartman District','Eastern Cape'),
  ('patensie','Patensie','Sarah Baartman District','Eastern Cape'),
  ('pearston','Pearston','Sarah Baartman District','Eastern Cape'),
  ('port-alfred','Port Alfred','Sarah Baartman District','Eastern Cape'),
  ('riebeek-east','Riebeek East','Sarah Baartman District','Eastern Cape'),
  ('somerset-east','Somerset East','Sarah Baartman District','Eastern Cape'),
  ('st-francis-bay','St Francis Bay','Sarah Baartman District','Eastern Cape'),
  ('storms-river','Storms River','Sarah Baartman District','Eastern Cape'),
  ('bellville','Bellville','City of Cape Town Metro','Western Cape'),
  ('cape-town','Cape Town','City of Cape Town Metro','Western Cape'),
  ('durbanville','Durbanville','City of Cape Town Metro','Western Cape'),
  ('goodwood','Goodwood','City of Cape Town Metro','Western Cape'),
  ('hout-bay','Hout Bay','City of Cape Town Metro','Western Cape'),
  ('khayelitsha','Khayelitsha','City of Cape Town Metro','Western Cape'),
  ('mitchells-plain','Mitchells Plain','City of Cape Town Metro','Western Cape'),
  ('simon-s-town','Simon''s Town','City of Cape Town Metro','Western Cape'),
  ('somerset-west','Somerset West','City of Cape Town Metro','Western Cape'),
  ('strand','Strand','City of Cape Town Metro','Western Cape'),
  ('ashton','Ashton','Cape Winelands District','Western Cape'),
  ('ceres','Ceres','Cape Winelands District','Western Cape'),
  ('franschhoek','Franschhoek','Cape Winelands District','Western Cape'),
  ('mcgregor','McGregor','Cape Winelands District','Western Cape'),
  ('montagu','Montagu','Cape Winelands District','Western Cape'),
  ('paarl','Paarl','Cape Winelands District','Western Cape'),
  ('robertson','Robertson','Cape Winelands District','Western Cape'),
  ('stellenbosch','Stellenbosch','Cape Winelands District','Western Cape'),
  ('tulbagh','Tulbagh','Cape Winelands District','Western Cape'),
  ('wellington','Wellington','Cape Winelands District','Western Cape'),
  ('worcester','Worcester','Cape Winelands District','Western Cape'),
  ('beaufort-west','Beaufort West','Central Karoo District','Western Cape'),
  ('laingsburg','Laingsburg','Central Karoo District','Western Cape'),
  ('leeu-gamka','Leeu-Gamka','Central Karoo District','Western Cape'),
  ('merweville','Merweville','Central Karoo District','Western Cape'),
  ('murraysburg','Murraysburg','Central Karoo District','Western Cape'),
  ('prince-albert','Prince Albert','Central Karoo District','Western Cape'),
  ('albertinia','Albertinia','Garden Route District','Western Cape'),
  ('calitzdorp','Calitzdorp','Garden Route District','Western Cape'),
  ('george','George','Garden Route District','Western Cape'),
  ('great-brak-river','Great Brak River','Garden Route District','Western Cape'),
  ('knysna','Knysna','Garden Route District','Western Cape'),
  ('mossel-bay','Mossel Bay','Garden Route District','Western Cape'),
  ('oudtshoorn','Oudtshoorn','Garden Route District','Western Cape'),
  ('plettenberg-bay','Plettenberg Bay','Garden Route District','Western Cape'),
  ('riversdale','Riversdale','Garden Route District','Western Cape'),
  ('uniondale','Uniondale','Garden Route District','Western Cape'),
  ('bredasdorp','Bredasdorp','Overberg District','Western Cape'),
  ('caledon','Caledon','Overberg District','Western Cape'),
  ('gansbaai','Gansbaai','Overberg District','Western Cape'),
  ('grabouw','Grabouw','Overberg District','Western Cape'),
  ('hermanus','Hermanus','Overberg District','Western Cape'),
  ('napier','Napier','Overberg District','Western Cape'),
  ('riviersonderend','Riviersonderend','Overberg District','Western Cape'),
  ('stanford','Stanford','Overberg District','Western Cape'),
  ('swellendam','Swellendam','Overberg District','Western Cape'),
  ('villiersdorp','Villiersdorp','Overberg District','Western Cape'),
  ('citrusdal','Citrusdal','West Coast District','Western Cape'),
  ('clanwilliam','Clanwilliam','West Coast District','Western Cape'),
  ('darling','Darling','West Coast District','Western Cape'),
  ('lamberts-bay','Lamberts Bay','West Coast District','Western Cape'),
  ('langebaan','Langebaan','West Coast District','Western Cape'),
  ('malmesbury','Malmesbury','West Coast District','Western Cape'),
  ('piketberg','Piketberg','West Coast District','Western Cape'),
  ('porterville','Porterville','West Coast District','Western Cape'),
  ('saldanha','Saldanha','West Coast District','Western Cape'),
  ('vredenburg','Vredenburg','West Coast District','Western Cape'),
  ('vredendal','Vredendal','West Coast District','Western Cape'),
  ('barkly-west','Barkly West','Frances Baard District','Northern Cape'),
  ('hartswater','Hartswater','Frances Baard District','Northern Cape'),
  ('jan-kempdorp','Jan Kempdorp','Frances Baard District','Northern Cape'),
  ('kimberley','Kimberley','Frances Baard District','Northern Cape'),
  ('warrenton','Warrenton','Frances Baard District','Northern Cape'),
  ('hotazel','Hotazel','John Taolo Gaetsewe District','Northern Cape'),
  ('kathu','Kathu','John Taolo Gaetsewe District','Northern Cape'),
  ('kuruman','Kuruman','John Taolo Gaetsewe District','Northern Cape'),
  ('mothibistad','Mothibistad','John Taolo Gaetsewe District','Northern Cape'),
  ('severn','Severn','John Taolo Gaetsewe District','Northern Cape'),
  ('van-zylsrus','Van Zylsrus','John Taolo Gaetsewe District','Northern Cape'),
  ('aggeneys','Aggeneys','Namakwa District','Northern Cape'),
  ('alexander-bay','Alexander Bay','Namakwa District','Northern Cape'),
  ('calvinia','Calvinia','Namakwa District','Northern Cape'),
  ('garies','Garies','Namakwa District','Northern Cape'),
  ('kamieskroon','Kamieskroon','Namakwa District','Northern Cape'),
  ('okiep','Okiep','Namakwa District','Northern Cape'),
  ('pofadder','Pofadder','Namakwa District','Northern Cape'),
  ('port-nolloth','Port Nolloth','Namakwa District','Northern Cape'),
  ('springbok','Springbok','Namakwa District','Northern Cape'),
  ('britstown','Britstown','Pixley ka Seme District','Northern Cape'),
  ('colesberg','Colesberg','Pixley ka Seme District','Northern Cape'),
  ('de-aar','De Aar','Pixley ka Seme District','Northern Cape'),
  ('hanover','Hanover','Pixley ka Seme District','Northern Cape'),
  ('hopetown','Hopetown','Pixley ka Seme District','Northern Cape'),
  ('noupoort','Noupoort','Pixley ka Seme District','Northern Cape'),
  ('philipstown','Philipstown','Pixley ka Seme District','Northern Cape'),
  ('prieska','Prieska','Pixley ka Seme District','Northern Cape'),
  ('victoria-west','Victoria West','Pixley ka Seme District','Northern Cape'),
  ('augrabies','Augrabies','ZF Mgcawu District','Northern Cape'),
  ('groblershoop','Groblershoop','ZF Mgcawu District','Northern Cape'),
  ('kakamas','Kakamas','ZF Mgcawu District','Northern Cape'),
  ('keimoes','Keimoes','ZF Mgcawu District','Northern Cape'),
  ('postmasburg','Postmasburg','ZF Mgcawu District','Northern Cape'),
  ('rietfontein','Rietfontein','ZF Mgcawu District','Northern Cape'),
  ('upington','Upington','ZF Mgcawu District','Northern Cape'),
  ('bloemfontein','Bloemfontein','Mangaung Metro','Free State'),
  ('botshabelo','Botshabelo','Mangaung Metro','Free State'),
  ('dewetsdorp','Dewetsdorp','Mangaung Metro','Free State'),
  ('thaba-nchu','Thaba Nchu','Mangaung Metro','Free State'),
  ('heilbron','Heilbron','Fezile Dabi District','Free State'),
  ('kroonstad','Kroonstad','Fezile Dabi District','Free State'),
  ('oranjeville','Oranjeville','Fezile Dabi District','Free State'),
  ('parys','Parys','Fezile Dabi District','Free State'),
  ('sasolburg','Sasolburg','Fezile Dabi District','Free State'),
  ('villiers','Villiers','Fezile Dabi District','Free State'),
  ('vredefort','Vredefort','Fezile Dabi District','Free State'),
  ('bothaville','Bothaville','Lejweleputswa District','Free State'),
  ('hennenman','Hennenman','Lejweleputswa District','Free State'),
  ('odendaalsrus','Odendaalsrus','Lejweleputswa District','Free State'),
  ('ventersburg','Ventersburg','Lejweleputswa District','Free State'),
  ('virginia','Virginia','Lejweleputswa District','Free State'),
  ('welkom','Welkom','Lejweleputswa District','Free State'),
  ('wesselsbron','Wesselsbron','Lejweleputswa District','Free State'),
  ('bethlehem','Bethlehem','Thabo Mofutsanyana District','Free State'),
  ('clarens','Clarens','Thabo Mofutsanyana District','Free State'),
  ('ficksburg','Ficksburg','Thabo Mofutsanyana District','Free State'),
  ('fouriesburg','Fouriesburg','Thabo Mofutsanyana District','Free State'),
  ('harrismith','Harrismith','Thabo Mofutsanyana District','Free State'),
  ('ladybrand','Ladybrand','Thabo Mofutsanyana District','Free State'),
  ('phuthaditjhaba','Phuthaditjhaba','Thabo Mofutsanyana District','Free State'),
  ('reitz','Reitz','Thabo Mofutsanyana District','Free State'),
  ('senekal','Senekal','Thabo Mofutsanyana District','Free State'),
  ('bethulie','Bethulie','Xhariep District','Free State'),
  ('fauresmith','Fauresmith','Xhariep District','Free State'),
  ('jagersfontein','Jagersfontein','Xhariep District','Free State'),
  ('koffiefontein','Koffiefontein','Xhariep District','Free State'),
  ('philippolis','Philippolis','Xhariep District','Free State'),
  ('reddersburg','Reddersburg','Xhariep District','Free State'),
  ('smithfield','Smithfield','Xhariep District','Free State'),
  ('trompsburg','Trompsburg','Xhariep District','Free State'),
  ('alexandra','Alexandra','City of Johannesburg Metro','Gauteng'),
  ('johannesburg','Johannesburg','City of Johannesburg Metro','Gauteng'),
  ('lenasia','Lenasia','City of Johannesburg Metro','Gauteng'),
  ('midrand','Midrand','City of Johannesburg Metro','Gauteng'),
  ('randburg','Randburg','City of Johannesburg Metro','Gauteng'),
  ('roodepoort','Roodepoort','City of Johannesburg Metro','Gauteng'),
  ('sandton','Sandton','City of Johannesburg Metro','Gauteng'),
  ('soweto','Soweto','City of Johannesburg Metro','Gauteng'),
  ('akasia','Akasia','City of Tshwane Metro','Gauteng'),
  ('bronkhorstspruit','Bronkhorstspruit','City of Tshwane Metro','Gauteng'),
  ('centurion','Centurion','City of Tshwane Metro','Gauteng'),
  ('cullinan','Cullinan','City of Tshwane Metro','Gauteng'),
  ('hammanskraal','Hammanskraal','City of Tshwane Metro','Gauteng'),
  ('mamelodi','Mamelodi','City of Tshwane Metro','Gauteng'),
  ('pretoria','Pretoria','City of Tshwane Metro','Gauteng'),
  ('soshanguve','Soshanguve','City of Tshwane Metro','Gauteng'),
  ('alberton','Alberton','Ekurhuleni Metro','Gauteng'),
  ('benoni','Benoni','Ekurhuleni Metro','Gauteng'),
  ('boksburg','Boksburg','Ekurhuleni Metro','Gauteng'),
  ('brakpan','Brakpan','Ekurhuleni Metro','Gauteng'),
  ('edenvale','Edenvale','Ekurhuleni Metro','Gauteng'),
  ('germiston','Germiston','Ekurhuleni Metro','Gauteng'),
  ('kempton-park','Kempton Park','Ekurhuleni Metro','Gauteng'),
  ('nigel','Nigel','Ekurhuleni Metro','Gauteng'),
  ('springs','Springs','Ekurhuleni Metro','Gauteng'),
  ('vosloorus','Vosloorus','Ekurhuleni Metro','Gauteng'),
  ('heidelberg','Heidelberg','Sedibeng District','Gauteng'),
  ('meyerton','Meyerton','Sedibeng District','Gauteng'),
  ('vanderbijlpark','Vanderbijlpark','Sedibeng District','Gauteng'),
  ('vereeniging','Vereeniging','Sedibeng District','Gauteng'),
  ('walkerville','Walkerville','Sedibeng District','Gauteng'),
  ('carletonville','Carletonville','West Rand District','Gauteng'),
  ('krugersdorp','Krugersdorp','West Rand District','Gauteng'),
  ('magaliesburg','Magaliesburg','West Rand District','Gauteng'),
  ('randfontein','Randfontein','West Rand District','Gauteng'),
  ('westonaria','Westonaria','West Rand District','Gauteng'),
  ('amanzimtoti','Amanzimtoti','eThekwini Metro','KwaZulu-Natal'),
  ('chatsworth','Chatsworth','eThekwini Metro','KwaZulu-Natal'),
  ('durban','Durban','eThekwini Metro','KwaZulu-Natal'),
  ('kwamashu','KwaMashu','eThekwini Metro','KwaZulu-Natal'),
  ('phoenix','Phoenix','eThekwini Metro','KwaZulu-Natal'),
  ('pinetown','Pinetown','eThekwini Metro','KwaZulu-Natal'),
  ('umhlanga','Umhlanga','eThekwini Metro','KwaZulu-Natal'),
  ('umlazi','Umlazi','eThekwini Metro','KwaZulu-Natal'),
  ('dannhauser','Dannhauser','Amajuba District','KwaZulu-Natal'),
  ('madadeni','Madadeni','Amajuba District','KwaZulu-Natal'),
  ('newcastle','Newcastle','Amajuba District','KwaZulu-Natal'),
  ('utrecht','Utrecht','Amajuba District','KwaZulu-Natal'),
  ('creighton','Creighton','Harry Gwala District','KwaZulu-Natal'),
  ('himeville','Himeville','Harry Gwala District','KwaZulu-Natal'),
  ('ixopo','Ixopo','Harry Gwala District','KwaZulu-Natal'),
  ('kokstad','Kokstad','Harry Gwala District','KwaZulu-Natal'),
  ('ballito','Ballito','iLembe District','KwaZulu-Natal'),
  ('kwadukuza','KwaDukuza','iLembe District','KwaZulu-Natal'),
  ('mandeni','Mandeni','iLembe District','KwaZulu-Natal'),
  ('ndwedwe','Ndwedwe','iLembe District','KwaZulu-Natal'),
  ('harding','Harding','Ugu District','KwaZulu-Natal'),
  ('hibberdene','Hibberdene','Ugu District','KwaZulu-Natal'),
  ('margate','Margate','Ugu District','KwaZulu-Natal'),
  ('port-shepstone','Port Shepstone','Ugu District','KwaZulu-Natal'),
  ('scottburgh','Scottburgh','Ugu District','KwaZulu-Natal'),
  ('shelly-beach','Shelly Beach','Ugu District','KwaZulu-Natal'),
  ('camperdown','Camperdown','uMgungundlovu District','KwaZulu-Natal'),
  ('howick','Howick','uMgungundlovu District','KwaZulu-Natal'),
  ('mooi-river','Mooi River','uMgungundlovu District','KwaZulu-Natal'),
  ('pietermaritzburg','Pietermaritzburg','uMgungundlovu District','KwaZulu-Natal'),
  ('richmond','Richmond','uMgungundlovu District','KwaZulu-Natal'),
  ('wartburg','Wartburg','uMgungundlovu District','KwaZulu-Natal'),
  ('hlabisa','Hlabisa','uMkhanyakude District','KwaZulu-Natal'),
  ('hluhluwe','Hluhluwe','uMkhanyakude District','KwaZulu-Natal'),
  ('jozini','Jozini','uMkhanyakude District','KwaZulu-Natal'),
  ('manguzi','Manguzi','uMkhanyakude District','KwaZulu-Natal'),
  ('mtubatuba','Mtubatuba','uMkhanyakude District','KwaZulu-Natal'),
  ('dundee','Dundee','uMzinyathi District','KwaZulu-Natal'),
  ('greytown','Greytown','uMzinyathi District','KwaZulu-Natal'),
  ('nquthu','Nquthu','uMzinyathi District','KwaZulu-Natal'),
  ('tugela-ferry','Tugela Ferry','uMzinyathi District','KwaZulu-Natal'),
  ('bergville','Bergville','uThukela District','KwaZulu-Natal'),
  ('colenso','Colenso','uThukela District','KwaZulu-Natal'),
  ('estcourt','Estcourt','uThukela District','KwaZulu-Natal'),
  ('ladysmith','Ladysmith','uThukela District','KwaZulu-Natal'),
  ('louwsburg','Louwsburg','Zululand District','KwaZulu-Natal'),
  ('nongoma','Nongoma','Zululand District','KwaZulu-Natal'),
  ('pongola','Pongola','Zululand District','KwaZulu-Natal'),
  ('ulundi','Ulundi','Zululand District','KwaZulu-Natal'),
  ('vryheid','Vryheid','Zululand District','KwaZulu-Natal'),
  ('barberton','Barberton','Ehlanzeni District','Mpumalanga'),
  ('bushbuckridge','Bushbuckridge','Ehlanzeni District','Mpumalanga'),
  ('graskop','Graskop','Ehlanzeni District','Mpumalanga'),
  ('hazyview','Hazyview','Ehlanzeni District','Mpumalanga'),
  ('komatipoort','Komatipoort','Ehlanzeni District','Mpumalanga'),
  ('lydenburg','Lydenburg','Ehlanzeni District','Mpumalanga'),
  ('malelane','Malelane','Ehlanzeni District','Mpumalanga'),
  ('mbombela','Mbombela','Ehlanzeni District','Mpumalanga'),
  ('sabie','Sabie','Ehlanzeni District','Mpumalanga'),
  ('white-river','White River','Ehlanzeni District','Mpumalanga'),
  ('amersfoort','Amersfoort','Gert Sibande District','Mpumalanga'),
  ('bethal','Bethal','Gert Sibande District','Mpumalanga'),
  ('breyten','Breyten','Gert Sibande District','Mpumalanga'),
  ('carolina','Carolina','Gert Sibande District','Mpumalanga'),
  ('ermelo','Ermelo','Gert Sibande District','Mpumalanga'),
  ('piet-retief','Piet Retief','Gert Sibande District','Mpumalanga'),
  ('secunda','Secunda','Gert Sibande District','Mpumalanga'),
  ('standerton','Standerton','Gert Sibande District','Mpumalanga'),
  ('delmas','Delmas','Nkangala District','Mpumalanga'),
  ('emakhazeni','eMakhazeni','Nkangala District','Mpumalanga'),
  ('emalahleni','Emalahleni','Nkangala District','Mpumalanga'),
  ('groblersdal','Groblersdal','Nkangala District','Mpumalanga'),
  ('kwamhlanga','Kwamhlanga','Nkangala District','Mpumalanga'),
  ('middelburg','Middelburg','Nkangala District','Mpumalanga'),
  ('siyabuswa','Siyabuswa','Nkangala District','Mpumalanga'),
  ('dendron','Dendron','Capricorn District','Limpopo'),
  ('lebowakgomo','Lebowakgomo','Capricorn District','Limpopo'),
  ('mankweng','Mankweng','Capricorn District','Limpopo'),
  ('mogwadi','Mogwadi','Capricorn District','Limpopo'),
  ('polokwane','Polokwane','Capricorn District','Limpopo'),
  ('seshego','Seshego','Capricorn District','Limpopo'),
  ('giyani','Giyani','Mopani District','Limpopo'),
  ('gravelotte','Gravelotte','Mopani District','Limpopo'),
  ('hoedspruit','Hoedspruit','Mopani District','Limpopo'),
  ('modjadjiskloof','Modjadjiskloof','Mopani District','Limpopo'),
  ('phalaborwa','Phalaborwa','Mopani District','Limpopo'),
  ('tzaneen','Tzaneen','Mopani District','Limpopo'),
  ('burgersfort','Burgersfort','Sekhukhune District','Limpopo'),
  ('groblersdal','Groblersdal','Sekhukhune District','Limpopo'),
  ('jane-furse','Jane Furse','Sekhukhune District','Limpopo'),
  ('marble-hall','Marble Hall','Sekhukhune District','Limpopo'),
  ('ohrigstad','Ohrigstad','Sekhukhune District','Limpopo'),
  ('steelpoort','Steelpoort','Sekhukhune District','Limpopo'),
  ('louis-trichardt','Louis Trichardt','Vhembe District','Limpopo'),
  ('malamulele','Malamulele','Vhembe District','Limpopo'),
  ('musina','Musina','Vhembe District','Limpopo'),
  ('mutale','Mutale','Vhembe District','Limpopo'),
  ('sibasa','Sibasa','Vhembe District','Limpopo'),
  ('thohoyandou','Thohoyandou','Vhembe District','Limpopo'),
  ('bela-bela','Bela-Bela','Waterberg District','Limpopo'),
  ('lephalale','Lephalale','Waterberg District','Limpopo'),
  ('modimolle','Modimolle','Waterberg District','Limpopo'),
  ('mokopane','Mokopane','Waterberg District','Limpopo'),
  ('thabazimbi','Thabazimbi','Waterberg District','Limpopo'),
  ('vaalwater','Vaalwater','Waterberg District','Limpopo'),
  ('brits','Brits','Bojanala Platinum District','North West'),
  ('groot-marico','Groot Marico','Bojanala Platinum District','North West'),
  ('hartbeespoort','Hartbeespoort','Bojanala Platinum District','North West'),
  ('koster','Koster','Bojanala Platinum District','North West'),
  ('mogwase','Mogwase','Bojanala Platinum District','North West'),
  ('rustenburg','Rustenburg','Bojanala Platinum District','North West'),
  ('zeerust','Zeerust','Bojanala Platinum District','North West'),
  ('klerksdorp','Klerksdorp','Dr Kenneth Kaunda District','North West'),
  ('orkney','Orkney','Dr Kenneth Kaunda District','North West'),
  ('potchefstroom','Potchefstroom','Dr Kenneth Kaunda District','North West'),
  ('stilfontein','Stilfontein','Dr Kenneth Kaunda District','North West'),
  ('ventersdorp','Ventersdorp','Dr Kenneth Kaunda District','North West'),
  ('wolmaransstad','Wolmaransstad','Dr Kenneth Kaunda District','North West'),
  ('bloemhof','Bloemhof','Dr Ruth Segomotsi Mompati District','North West'),
  ('christiana','Christiana','Dr Ruth Segomotsi Mompati District','North West'),
  ('schweizer-reneke','Schweizer-Reneke','Dr Ruth Segomotsi Mompati District','North West'),
  ('stella','Stella','Dr Ruth Segomotsi Mompati District','North West'),
  ('taung','Taung','Dr Ruth Segomotsi Mompati District','North West'),
  ('vryburg','Vryburg','Dr Ruth Segomotsi Mompati District','North West'),
  ('delareyville','Delareyville','Ngaka Modiri Molema District','North West'),
  ('lichtenburg','Lichtenburg','Ngaka Modiri Molema District','North West'),
  ('mahikeng','Mahikeng','Ngaka Modiri Molema District','North West'),
  ('mmabatho','Mmabatho','Ngaka Modiri Molema District','North West'),
  ('sannieshof','Sannieshof','Ngaka Modiri Molema District','North West'),
  ('zeerust','Zeerust','Ngaka Modiri Molema District','North West')
on conflict (id, district) do update set name = excluded.name, province = excluded.province;

-- 1) Resident contact details --------------------------------------------------
-- The app never had a phone number on the profile — numbers were typed per claim.
-- A municipality wanting to phone somebody shouldn't have to hunt through claims.

alter table public.profiles add column if not exists phone text;

-- Defaults to true: the municipality sees everybody unless a resident opts out.
alter table public.profiles
  add column if not exists share_contact boolean not null default true;

-- Residents edit these two themselves from My Area, which the app never needed
-- before. Two things have to be true for that to be safe:
--
--   (a) a row-level rule saying you may only touch your own row, and
--   (b) a column-level rule saying which columns. Without (b), "update your own
--       profile" also means "set is_admin = true on yourself", which would hand
--       the whole site to anybody with an account.
--
-- Postgres won't let a column-level revoke override a table-level grant, so the
-- table grant goes and comes back column by column, minus is_admin. Same trick as
-- the invite_code column in supabase-group-admins.sql.

alter table public.profiles enable row level security;

drop policy if exists "read own profile" on public.profiles;
create policy "read own profile"
  on public.profiles for select
  using (id = auth.uid());

drop policy if exists "insert own profile" on public.profiles;
create policy "insert own profile"
  on public.profiles for insert to authenticated
  with check (id = auth.uid());

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile"
  on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

revoke update on public.profiles from anon, authenticated;
grant update (name, town_id, phone, share_contact) on public.profiles to authenticated;

-- 2) The councils themselves ----------------------------------------------------
-- One row per district / metro — the level the app already calls "the local
-- government" (see the comment above `provinces` in index.html). `name` is the
-- municipality's own name for itself ("Kouga Local Municipality"), which is often
-- not the district name.

create table if not exists public.councils (
  id             uuid primary key default gen_random_uuid(),
  district       text not null unique,
  province       text not null,
  name           text not null,
  -- How to reach them about anything not on the list
  contact_office text,
  contact_person text,
  contact_role   text,
  phone          text,
  email          text,
  address        text,
  hours          text,
  notes          text,
  -- Nothing shows on the map until they say it's ready
  published      boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table if not exists public.council_members (
  council_id uuid not null references public.councils(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text not null default 'officer' check (role in ('officer','lead')),
  created_at timestamptz not null default now(),
  primary key (council_id, user_id)
);

-- 3) The rules ------------------------------------------------------------------
-- One row per activity. town_id = '' means "everywhere in this district"; a row
-- with a real town_id overrides the district row for that town, because a beachfront
-- town and a farming town don't always want the same answer.
-- Empty string rather than NULL so the unique key actually bites.

create table if not exists public.council_rules (
  id         uuid primary key default gen_random_uuid(),
  council_id uuid not null references public.councils(id) on delete cascade,
  town_id    text not null default '',
  activity   text not null,
  stance     text not null check (stance in ('allowed','ask','no')),
  note       text,
  updated_at timestamptz not null default now(),
  unique (council_id, town_id, activity)
);

create index if not exists council_rules_council_idx on public.council_rules(council_id);

-- 4) Applying for a council account ---------------------------------------------

create table if not exists public.council_applications (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  district     text not null,
  province     text,
  municipality text not null,
  person       text,
  job_title    text,
  work_email   text,
  phone        text,
  note         text,
  status       text not null default 'pending' check (status in ('pending','approved','declined')),
  created_at   timestamptz not null default now(),
  decided_by   uuid references auth.users(id),
  decided_at   timestamptz
);

create index if not exists council_applications_status_idx on public.council_applications(status);

-- 5) Who looked at the resident list ---------------------------------------------

create table if not exists public.council_access_log (
  id         bigserial primary key,
  council_id uuid not null references public.councils(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  rows_seen  int not null,
  at         timestamptz not null default now()
);

create index if not exists council_access_log_council_idx on public.council_access_log(council_id, at desc);

-- 6) Helper functions -------------------------------------------------------------
-- SECURITY DEFINER for the same reason as the ones in the earlier two files: a
-- policy that queried these tables directly would recurse into itself.

create or replace function public.is_site_admin()
returns boolean
language sql security definer set search_path = public stable
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.is_council_member(c uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1 from public.council_members m
    where m.council_id = c and m.user_id = auth.uid()
  );
$$;

-- The council this signed-in person speaks for, if any. The app calls this on
-- sign-in to decide whether the Council tab exists at all.
create or replace function public.my_council()
returns table (
  id uuid, district text, province text, name text,
  contact_office text, contact_person text, contact_role text,
  phone text, email text, address text, hours text, notes text,
  published boolean, member_role text
)
language sql security definer set search_path = public stable
as $$
  select c.id, c.district, c.province, c.name,
         c.contact_office, c.contact_person, c.contact_role,
         c.phone, c.email, c.address, c.hours, c.notes,
         c.published, m.role
    from public.councils c
    join public.council_members m on m.council_id = c.id
   where m.user_id = auth.uid();
$$;

grant execute on function public.is_site_admin()          to authenticated;
grant execute on function public.is_council_member(uuid)  to authenticated;
grant execute on function public.my_council()             to authenticated;

-- 7) Policies ---------------------------------------------------------------------

alter table public.councils             enable row level security;
alter table public.council_members      enable row level security;
alter table public.council_rules        enable row level security;
alter table public.council_applications enable row level security;
alter table public.council_access_log   enable row level security;

-- A published council is public — that's the whole point of it. An unpublished one
-- is a draft only its own people (and a site admin) can see.
drop policy if exists "read published councils" on public.councils;
create policy "read published councils"
  on public.councils for select
  using (published or public.is_council_member(id) or public.is_site_admin());

-- Councils edit their own details. They can't create or delete themselves — that
-- happens through approve_council_application().
drop policy if exists "council edits itself" on public.councils;
create policy "council edits itself"
  on public.councils for update
  using (public.is_council_member(id) or public.is_site_admin())
  with check (public.is_council_member(id) or public.is_site_admin());

-- Rules of a published council are readable by anyone, signed in or not.
drop policy if exists "read rules of published councils" on public.council_rules;
create policy "read rules of published councils"
  on public.council_rules for select
  using (exists (select 1 from public.councils c
                  where c.id = council_id
                    and (c.published or public.is_council_member(c.id) or public.is_site_admin())));

drop policy if exists "council writes own rules" on public.council_rules;
create policy "council writes own rules"
  on public.council_rules for insert
  with check (public.is_council_member(council_id));

drop policy if exists "council updates own rules" on public.council_rules;
create policy "council updates own rules"
  on public.council_rules for update
  using (public.is_council_member(council_id))
  with check (public.is_council_member(council_id));

drop policy if exists "council deletes own rules" on public.council_rules;
create policy "council deletes own rules"
  on public.council_rules for delete
  using (public.is_council_member(council_id));

-- You can see who else is on your own council.
drop policy if exists "read own council members" on public.council_members;
create policy "read own council members"
  on public.council_members for select
  using (user_id = auth.uid() or public.is_council_member(council_id) or public.is_site_admin());

-- Applications: anybody signed in may lodge one for themselves and watch it; only
-- a site admin sees the queue.
drop policy if exists "apply for council access" on public.council_applications;
create policy "apply for council access"
  on public.council_applications for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "read own application" on public.council_applications;
create policy "read own application"
  on public.council_applications for select
  using (user_id = auth.uid() or public.is_site_admin());

drop policy if exists "site admin decides applications" on public.council_applications;
create policy "site admin decides applications"
  on public.council_applications for update
  using (public.is_site_admin()) with check (public.is_site_admin());

-- The access log is written by council_residents() (which runs as definer, so it
-- bypasses this) and read by the council it belongs to and by a site admin.
drop policy if exists "read own access log" on public.council_access_log;
create policy "read own access log"
  on public.council_access_log for select
  using (public.is_council_member(council_id) or public.is_site_admin());

-- 8) The resident list -------------------------------------------------------------
-- The sensitive one. Everything about it is decided here rather than in the browser:
-- which district you may ask about, which residents count as "yours", whether a
-- resident's contact details come back at all, and the fact that the read is logged.
--
-- "In your area" means either of:
--   * they told sign-up they live in a town of your district, or
--   * they've claimed an area, or offered help, in a town of your district
-- The second half matters — plenty of people look after a space in a town they don't
-- live in, and the municipality still needs to be able to reach them.

create or replace function public.council_residents(c uuid)
returns table (
  -- Deliberately not called user_id: these output names are plpgsql variables, and
  -- one called user_id would sit in the same namespace as the user_id column this
  -- function writes to council_access_log. Sidestepping that beats relying on the
  -- substitution rules to keep them apart.
  resident_id    uuid,
  name           text,
  email          text,
  phone          text,
  town_id        text,
  town_name      text,
  contact_hidden boolean,
  areas_claimed  int,
  help_offered   int,
  lives_here     boolean
)
language plpgsql security definer set search_path = public, auth
as $$
declare
  d text;
  n int;
begin
  if not public.is_council_member(c) and not public.is_site_admin() then
    raise exception 'That is not your district';
  end if;

  select district into d from public.councils where id = c;
  if d is null then
    raise exception 'No such council';
  end if;

  -- Counted first so the log entry is written even if the caller reads one row and
  -- walks away. The people CTE is repeated below rather than parked in a temp table,
  -- which would collide with itself if this ran twice inside one transaction.
  with district_towns as (
    select t.id from public.towns t where t.district = d
  ),
  people as (
    select p.id as uid from public.profiles p
     where p.town_id in (select id from district_towns)
    union
    select a.owner_id from public.areas a
     where a.town_id in (select id from district_towns) and a.owner_id is not null
    union
    select h.owner_id from public.helper_areas h
     where h.town_id in (select id from district_towns) and h.owner_id is not null
  )
  select count(*)::int into n from people;

  insert into public.council_access_log (council_id, user_id, rows_seen)
  values (c, auth.uid(), n);

  return query
  with district_towns as (
    select t.id from public.towns t where t.district = d
  ),
  -- Everyone with a foot in the district, however they got there
  people as (
    select p.id as uid, true as lives
      from public.profiles p
     where p.town_id in (select id from district_towns)
    union
    select a.owner_id, false
      from public.areas a
     where a.town_id in (select id from district_towns)
       and a.owner_id is not null
    union
    select h.owner_id, false
      from public.helper_areas h
     where h.town_id in (select id from district_towns)
       and h.owner_id is not null
  ),
  folded as (
    select uid, bool_or(lives) as lives from people group by uid
  )
  select f.uid,
         coalesce(p.name, 'Neighbour') as name,
         case when coalesce(p.share_contact, true) then u.email::text end as email,
         case when coalesce(p.share_contact, true)
              then coalesce(p.phone,
                            (select a.phone from public.areas a
                              where a.owner_id = f.uid and coalesce(a.phone,'') <> ''
                              order by a.created_at limit 1),
                            (select h.phone from public.helper_areas h
                              where h.owner_id = f.uid and coalesce(h.phone,'') <> ''
                              order by h.created_at limit 1))
         end as phone,
         p.town_id,
         (select t.name from public.towns t
           where t.id = p.town_id and t.district = d limit 1) as town_name,
         not coalesce(p.share_contact, true) as contact_hidden,
         (select count(*)::int from public.areas a
           where a.owner_id = f.uid and a.town_id in (select id from district_towns)) as areas_claimed,
         (select count(*)::int from public.helper_areas h
           where h.owner_id = f.uid and h.town_id in (select id from district_towns)) as help_offered,
         f.lives as lives_here
    from folded f
    left join public.profiles p on p.id = f.uid
    left join auth.users     u on u.id = f.uid
   order by 2;
end;
$$;

grant execute on function public.council_residents(uuid) to authenticated;

-- 9) Applying and approving ---------------------------------------------------------

create or replace function public.apply_for_council(
  p_district text, p_municipality text, p_person text,
  p_position text, p_work_email text, p_phone text, p_note text
)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  prov text;
  app_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Sign in first';
  end if;
  select province into prov from public.towns where district = p_district limit 1;
  if prov is null then
    raise exception 'Unknown district %', p_district;
  end if;
  -- One open application at a time, so a double tap doesn't fill the admin queue.
  if exists (select 1 from public.council_applications
              where user_id = auth.uid() and status = 'pending') then
    raise exception 'You already have an application waiting';
  end if;
  insert into public.council_applications
    (user_id, district, province, municipality, person, job_title, work_email, phone, note)
  values
    (auth.uid(), p_district, prov, p_municipality, p_person, p_position, p_work_email, p_phone, p_note)
  returning id into app_id;
  return app_id;
end;
$$;

-- Approving creates the council row for that district the first time round, then
-- adds the applicant to it. A second officer from the same municipality joins the
-- council that's already there.
create or replace function public.approve_council_application(p_app uuid)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  app public.council_applications%rowtype;
  cid uuid;
begin
  if not public.is_site_admin() then
    raise exception 'Only a site admin can approve council access';
  end if;
  select * into app from public.council_applications where id = p_app;
  if not found then
    raise exception 'No such application';
  end if;
  if app.status <> 'pending' then
    raise exception 'That application has already been decided';
  end if;

  select id into cid from public.councils where district = app.district;
  if cid is null then
    insert into public.councils (district, province, name, email, phone, contact_person, contact_role)
    values (app.district, app.province, app.municipality, app.work_email, app.phone, app.person, app.job_title)
    returning id into cid;
  end if;

  insert into public.council_members (council_id, user_id, role)
  values (cid, app.user_id, 'lead')
  on conflict (council_id, user_id) do nothing;

  update public.council_applications
     set status = 'approved', decided_by = auth.uid(), decided_at = now()
   where id = p_app;

  return cid;
end;
$$;

create or replace function public.decline_council_application(p_app uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.is_site_admin() then
    raise exception 'Only a site admin can decide council access';
  end if;
  update public.council_applications
     set status = 'declined', decided_by = auth.uid(), decided_at = now()
   where id = p_app and status = 'pending';
end;
$$;

grant execute on function public.apply_for_council(text,text,text,text,text,text,text) to authenticated;
grant execute on function public.approve_council_application(uuid) to authenticated;
grant execute on function public.decline_council_application(uuid) to authenticated;

-- 10) Reading the rules without signing in -------------------------------------------
-- The map shows a district's rules to anybody who lands on the site, so this one
-- read has to work for anon too. It only ever returns published councils.

create or replace function public.rules_for_district(d text)
returns table (
  council_id uuid, council_name text, district text, province text,
  contact_office text, contact_person text, contact_role text,
  phone text, email text, address text, hours text, notes text,
  town_id text, activity text, stance text, note text
)
language sql security definer set search_path = public stable
as $$
  select c.id, c.name, c.district, c.province,
         c.contact_office, c.contact_person, c.contact_role,
         c.phone, c.email, c.address, c.hours, c.notes,
         r.town_id, r.activity, r.stance, r.note
    from public.councils c
    left join public.council_rules r on r.council_id = c.id
   where c.district = d and c.published;
$$;

-- Which municipalities have published anything at all — the "these areas have rules"
-- list on the map page.
create or replace function public.published_councils()
returns table (
  council_id uuid, name text, district text, province text,
  allowed_count int, rule_count int
)
language sql security definer set search_path = public stable
as $$
  select c.id, c.name, c.district, c.province,
         count(*) filter (where r.stance = 'allowed' and r.town_id = '')::int,
         count(r.id)::int
    from public.councils c
    left join public.council_rules r on r.council_id = c.id
   where c.published
   group by c.id, c.name, c.district, c.province
   order by c.district;
$$;

grant execute on function public.rules_for_district(text) to anon, authenticated;
grant execute on function public.published_councils()     to anon, authenticated;
