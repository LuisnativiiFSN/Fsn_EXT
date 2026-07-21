/*
    parametros de entrada:
        -parametro 1: Rec."Value Text 1" ->[TIENDA NO.: "No Tienda",TPVNUEVO: "Nuevo TPV"]
        -parametro 2: Rec."Value Text 2" ->[TIENDA NO.: "Tienda de referencia",TPVNUEVO: "TPV de referencia"]
        -parametro 3: Rec.Descripcion ->[TIENDA NO.: "Nombre de tienda",TPVNUEVO: "rango de CREF"]
        -parametro 4: Rec.valor ->[TIENDA NO.: "Direccion..Direccion 2",TPVNUEVO: "rango de FAC"]
        -parametro 5: Rec."string parameter 1 json" ->[TIENDA NO.: "zip code..poblacion",TPVNUEVO: "rango de TICKET"]
        -parametro 6: Rec."string parameter 2 json" ->[TIENDA NO.: "telefono",TPVNUEVO: "rango de NOCRE"]
*/
codeunit 50013 "FSN SetUp Init"
{
    trigger OnRun()
    begin
    end;

    #region Test
    var
        parameter: Record "FSN Parameter";

    procedure Test()
    var
        FileRead: DotNet File;
        RecRef: RecordRef;
        Jobject: JsonObject;
        _Jobject: JsonObject;
        Jarray: JsonArray;
        Jtoken: JsonToken;
        Jvalue: JsonValue;
        JsonText: Text;
        RecID: Integer;
    begin
        JsonText := FileRead.ReadAllText('C:/BCAddins/JSON/TablesToDeleteData.json');
        Jobject.ReadFrom(JsonText);
        Jobject.Get('LSC', Jtoken);
        Jarray := Jtoken.AsArray();
        foreach Jtoken in Jarray do begin
            _Jobject := Jtoken.AsObject();
            if _Jobject.Get('id', Jtoken) then begin
                Jvalue := Jtoken.AsValue();
                RecID := Jvalue.AsInteger();
                RecRef.Open(RecID, false);
                Message(RecRef.Name);
                RecRef.Close();
            end;
        end;
    end;
    #endregion

    #region [External Procedures]
    procedure DeleteProcress(CodeParameter: Code[10])
    var
        FileRead: DotNet File;
        RecRef: RecordRef;
        Jobject: JsonObject;
        _Jobject: JsonObject;
        Jarray: JsonArray;
        Jtoken: JsonToken;
        Jvalue: JsonValue;
        Codes: array[2] of Code[10];
        JsonText: Text;
        RecName: Text;
        RecID: Integer;
        loops: Integer;
        i: Integer;
    begin

        case
            codeParameter of
            'ALL':
                begin
                    Codes[1] := 'LSC';
                    Codes[2] := 'FSN';
                    loops := 2;
                end;
            else begin
                Codes[1] := CodeParameter;
                loops := 1;
            end;
        end;

        JsonText := FileRead.ReadAllText('C:/BCAddins/JSON/TablesToDeleteData.json');
        Jobject.ReadFrom(JsonText);
        for i := 1 to loops do begin
            Jobject.Get(Codes[i], Jtoken);
            Jarray := Jtoken.AsArray();
            foreach Jtoken in Jarray do begin
                _Jobject := Jtoken.AsObject();
                _Jobject.Get('name', Jtoken);
                Jvalue := Jtoken.AsValue();
                RecName := Jvalue.AsText();
                if _Jobject.Get('id', Jtoken) then begin
                    Jvalue := Jtoken.AsValue();
                    RecID := Jvalue.AsInteger();
                    RecRef.Open(RecID, false);
                    RecRef.DeleteAll();
                    RecRef.Close();
                end;
            end;
            Message('Se han eliminado los registros de ' + Codes[i]);
        end;
    end;

    procedure CreateNewTPV(var Rec: Record "FSN Parameter" temporary);
    var
        dist: Record "LSC Distribution Location";
        POSTerminal: record "LSC POS Terminal";
        NewPOSTerminal: record "LSC POS Terminal";
        LSCStore: record "LSC Store";
        LSCStoreRef: record "LSC Store";
        LSCRetailcalendar: record "LSC Retail Calendar";
        location: record "Location";
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
        SeriesArray: array[5] of code[25];
        initialArray: array[5] of code[20];
        finalArray: array[5] of code[20];
        descriptionArray: array[5] of text[100];
        HospArray: array[3] of code[20];
        SequenceArray: array[3] of Integer;
        i: Integer;
        NoTPV: code[4];
        NoTienda: code[30];
        NoSeriesCode: code[20];
        tienda: text;
        WithValidation: Boolean;
    begin
        #region "parametros HOSP"
        HospArray[1] := 'DELIVERY';
        HospArray[2] := 'TAKEAWAY';
        HospArray[3] := 'PRE-ORDER';
        SequenceArray[1] := 1;
        SequenceArray[2] := 3;
        SequenceArray[3] := 6;
        #endregion
        seriesArray[1] := 'CREF0';
        seriesArray[2] := 'FAC0';
        seriesArray[3] := 'TICKET0';
        seriesArray[4] := 'NOCRE0';
        seriesArray[5] := 'DEV-';

        Rec.Reset();
        Rec.Find('-');
        repeat
            if Rec.Codigo = 'TIENDA NO.' then begin
                if Rec."Value Text 1" = '' then begin
                    NoTienda := Rec."Value Text 1";
                end else begin
                    if not LSCStore.Get(Rec."Value Text 1") then begin
                        if LSCStoreRef.Get(Rec."Value Text 2") then;
                        LSCStore.Init();
                        LSCStore.TransferFields(LSCStoreRef);
                        LSCStore.Validate("No.", Rec."Value Text 1");
                        LSCSTore."Location Code" := '';
                        WithValidation := not dist.Get(LSCStore."No.");
                        LSCStore.Insert(WithValidation);
                        LSCStore.Validate(Name, Rec.Descripcion);
                        LSCStore.Validate(Address, CopyStr(Rec.Valor, 1, StrPos(Rec.Valor, '..') - 1));
                        LSCStore.Validate("Address 2", CopyStr(Rec.Valor, StrPos(Rec.Valor, '..') + 2));
                        LSCStore.Validate("Post Code", CopyStr(Rec."String Parameters 1 Json", 1, StrPos(Rec."String Parameters 1 Json", '..') - 1));
                        LSCStore.Validate("City", CopyStr(Rec."String Parameters 1 Json", StrPos(Rec."String Parameters 1 Json", '..') + 2));
                        LSCStore.Validate("Phone No.", Rec."String Parameters 2 Json");
                        LSCStore.Validate("store type", LSCStore."Store Type"::Store);
                        location.Init();
                        location.Validate("code", LSCStore."No.");
                        location.Validate("name", LSCStore.Name);
                        location.Insert(true);
                        if WithValidation then
                            LSCStore.Validate("Location Code", LSCStore."No.")
                        else
                            LSCStore."Location Code" := LSCStore."No.";

                        NoSeries.Init();
                        NoSeries.Code := 'DEC' + LSCStore."No.";
                        NoSeries.Validate(Description, 'Retail statemnet store ' + LSCStore."No.");
                        NoSeries.Insert(true);

                        NoSeriesLine.Init();
                        NoSeriesLine."Series Code" := NoSeries.Code;
                        if StrLen(LSCStore."No.") < 4 then begin
                            tienda := InsStr(LSCStore."No.", '0', 2);
                        end;
                        NoSeriesLine.Validate("Starting No.", tienda + ' - 000001');
                        NoSeriesLine.Insert(true);
                        LSCStore.Validate("Statement Nos.", NoSeries.Code);
                        LSCStore.Validate("Posted Statem. Nos.", NoSeries.Code);
                        LSCStore.Modify(true);

                        LSCRetailcalendar.Init();
                        LSCRetailcalendar.Validate("Calendar Type", LSCRetailcalendar."Calendar Type"::"Rest. Order Taking");
                        LSCRetailcalendar.Validate("Group Type", LSCRetailcalendar."Group Type"::Store);
                        LSCRetailcalendar.Validate(ID, LSCStore."No.");
                        LSCRetailcalendar.Validate(Description, LSCStore.Name);
                        LSCRetailcalendar.Insert(true);

                        for i := 1 to 3 do begin
                            CreateHosp(SequenceArray[i], HospArray[i], LSCStore."No.");
                        end;

                        NoTienda := LSCStore."No.";
                        Message('New POS Terminal ' + NoTienda + ' created');
                    end else begin
                        NoTienda := LSCStore."No.";
                    end;
                end;
            end;
            if Rec.Codigo = 'TPVNUEVO' then begin
                #region "Parametro Facturacion"
                initialArray[1] := CopyStr(Rec.Descripcion, 1, StrPos(Rec.Descripcion, '..') - 1);
                finalArray[1] := CopyStr(Rec.Descripcion, StrPos(Rec.Descripcion, '..') + 2);
                descriptionArray[1] := 'FACT. CREDITO FISCAL';
                initialArray[2] := CopyStr(Rec.Valor, 1, StrPos(Rec.Valor, '..') - 1);
                finalArray[2] := CopyStr(Rec.Valor, StrPos(Rec.Valor, '..') + 2);
                descriptionArray[2] := 'FACT. CONSUMIDOR FINAL';
                initialArray[3] := CopyStr(Rec."String Parameters 1 Json", 1, StrPos(Rec."String Parameters 1 Json", '..') - 1);
                finalArray[3] := CopyStr(Rec."String Parameters 1 Json", StrPos(Rec."String Parameters 1 Json", '..') + 2);
                descriptionArray[3] := 'TICKET';
                initialArray[4] := CopyStr(Rec."String Parameters 2 Json", 1, StrPos(Rec."String Parameters 2 Json", '..') - 1);
                finalArray[4] := CopyStr(Rec."String Parameters 2 Json", StrPos(Rec."String Parameters 2 Json", '..') + 2);
                descriptionArray[4] := 'NOTA DE CREDITO';
                initialArray[5] := '000001';
                finalArray[5] := '999999';
                descriptionArray[5] := 'Documento Devolucion Cons. Final';
                #endregion
                POSTerminal.Reset();
                if (Rec."Value Text 1" <> '') and (Rec."Value Text 1" <> Rec."Value Text 2") and (Rec."Value Text 2" <> '') then begin
                    if not POSTerminal.Get(Rec."Value Text 1") then begin
                        if POSTerminal.Get(Rec."Value Text 2") then begin
                            NoTPV := DelChr(Rec."Value Text 1", '=', 'PV#');
                            NewPOSTerminal.Init();
                            NewPOSTerminal.TransferFields(POSTerminal);
                            NewPOSTerminal."No." := Rec."Value Text 1";
                            NewPOSTerminal.Validate("EFT POS Terminal No.", Rec."Value Text 1");
                            NewPOSTerminal.Validate("Last Z-Report", 'Z000000');
                            NewPOSTerminal.Validate("Exclude from Cash Mgnt.", false);
                            if NoTienda <> '' then begin
                                LSCStore.get(NoTienda);
                                NewPOSTerminal.Validate("Store No.", NoTienda);
                                NewPOSTerminal.Validate(Description, LSCStore."No." + ' - ' + LSCStore.Name + ' ' + Rec."Value Text 1");
                            end else begin
                                LSCStore.get(POSTerminal."Store No.");
                                NewPOSTerminal.Validate(Description, POSTerminal."Store No." + ' - ' + LSCStore.Name + ' ' + Rec."Value Text 1");
                            end;
                            if Rec.Activo then begin
                                NewPOSTerminal.Validate("Interface Profile", '#FSNMASTER');
                                NewPOSTerminal.Validate("Menu Profile", '#FSNMASTER');
                                for i := 1 to 3 do begin
                                    if not GetHosp(SequenceArray[i], HospArray[i], NoTienda) then
                                        CreateHosp(SequenceArray[i], HospArray[i], NoTienda);
                                end;
                            end else begin
                                NewPOSTerminal.Validate("Interface Profile", '#FSNSLAVE');
                                NewPOSTerminal.validate("Menu Profile", '#FSNSLAVE');
                            end;
                            for i := 1 to 5 do begin
                                if not Rec.Activo and (SeriesArray[i] in ['CREF0', 'FAC0', 'NOCRE0']) then begin
                                    NoSeriesCode := GetNoSeries(SeriesArray[i], NoTPV, NoTienda);
                                end else begin
                                    NoSeriesCode := CreateNoSeries(SeriesArray[i], descriptionArray[i], initialArray[i], finalArray[i], NoTPV, NoTienda);
                                end;
                                case SeriesArray[i] of
                                    'CREF0':
                                        NewPOSTerminal.Validate("FSN No. Serie Credito Fiscal", NoSeriesCode);
                                    'FAC0':
                                        NewPOSTerminal.Validate("FSN No. Serie NCF Cons. Final", NoSeriesCode);
                                    'TICKET0':
                                        NewPOSTerminal.Validate("FSN No. Serie NCF Ticket", NoSeriesCode);
                                    'NOCRE0':
                                        NewPOSTerminal.Validate("FSN No. Serie Nota de Credito", NoSeriesCode);
                                    'DEV-':
                                        NewPOSTerminal.Validate("FSN No. Serie Nota de Credito", NoSeriesCode);
                                end;
                            end;
                            NewPOSTerminal.Insert(true);
                            Message('New POS Terminal ' + Rec."Value Text 1" + ' created');
                        end;
                    end
                end;
            end;
        until Rec.Next = 0;
    end;
    #endregion
    #region [local procedures]
    local procedure CreateHosp(pSequence: Integer; HospType: Code[20]; StoreNo: Code[10])
    var
        LSCHospitalityTypeNew: record "LSC Hospitality Type";
        LSCHospitalityTypeRef: record "LSC Hospitality Type";
    begin
        LSCHospitalityTypeRef.Reset();
        LSCHospitalityTypeRef.SetCurrentKey("Restaurant No.", Sequence, "Sales Type");
        LSCHospitalityTypeRef.SetRange("Restaurant No.", 'F50');
        LSCHospitalityTypeRef.SetRange("Sales Type", HospType);
        LSCHospitalityTypeRef.SetRange(Sequence, pSequence);
        if LSCHospitalityTypeRef.FindFirst() then begin
            LSCHospitalityTypeNew.Init();
            LSCHospitalityTypeNew.TransferFields(LSCHospitalityTypeRef);
            LSCHospitalityTypeNew.Validate("Restaurant No.", StoreNo);
            LSCHospitalityTypeNew.Insert(true);
        end;
    end;

    local procedure GetHosp(pSequence: Integer; HospType: Code[20]; StoreNo: Code[10]): Boolean
    var
        LSCHospitalityTypeRef: record "LSC Hospitality Type";
    begin
        LSCHospitalityTypeRef.Reset();
        LSCHospitalityTypeRef.SetCurrentKey("Restaurant No.", Sequence, "Sales Type");
        LSCHospitalityTypeRef.SetRange("Restaurant No.", StoreNo);
        LSCHospitalityTypeRef.SetRange("Sales Type", HospType);
        LSCHospitalityTypeRef.SetRange(Sequence, pSequence);
        if LSCHospitalityTypeRef.FindFirst() then
            exit(true);
        exit(false);
    end;

    local procedure CreateNoSeries(prefix: Code[25]; pDescription: Text[100]; StartingNo: Code[25]; EndingNo: Code[25]; NoTPV: code[4]; Notienda: Code[30]): Code[20]
    var
        NoSeries: Record "No. Series";
        NoSeriesLine: Record "No. Series Line";
    begin
        NoSeries.Init();
        if prefix in ['TICKET0', 'DEV-'] then
            NoSeries.Code := prefix + NoTPV
        else
            NoSeries.Code := prefix + NoTienda;
        NoSeriesLine.Init();
        NoSeriesLine."Series Code" := NoSeries.Code;
        NoSeries.Validate(Description, pDescription);
        NoSeries.Insert();
        NoSeriesLine.Validate("Starting No.", StartingNo);
        NoSeriesLine.Validate("Ending No.", EndingNo);
        NoSeriesline.Insert();
        exit(NoSeries.Code);
    end;

    local procedure GetNoSeries(prefix: Code[25]; NoTPV: code[4]; Notienda: Code[30]): Code[20]
    var
        NoSeries: Record "No. Series";
    begin
        if prefix in ['TICKET0', 'DEV-'] then begin
            if NoSeries.Get(prefix + NoTPV) then
                exit(NoSeries.Code);
        end else begin
            if NoSeries.Get(prefix + NoTienda) then
                exit(NoSeries.Code);
        end;
    end;
    #endregion


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Config. Package Management", 'OnModifyRecordDataFieldsOnAfterRecRefModify', '', true, true)]
    local procedure "Config. Package Management_OnModifyRecordDataFieldsOnAfterRecRefModify"(var RecRef: RecordRef)
    var
        Customer: Record Customer;
        POSSESION: Codeunit "LSC POS Session";
    begin
        if GParameter() then begin
            IF POSSESION.GetValue('CUSTOMERDEL') = 'TRUE' then begin
                RecRef.SetTable(Customer);
                if Customer."No." <> '' then begin
                    Customer.Delete(true);
                end;
            end;
        end;
    end;

    procedure GParameter(): Boolean
    var
        myInt: Integer;
    begin
        if (parameter.Get('ELIMINAR', 'P_CONF')) and (Parameter.Activo) then
            exit(true)
        else
            exit(false);
    end;
}