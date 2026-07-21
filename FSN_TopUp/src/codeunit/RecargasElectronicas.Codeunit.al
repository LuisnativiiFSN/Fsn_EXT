codeunit 50033 "FSN Recargas Electronicas"
{
    SingleInstance = true;

    var
        POSCtrl: Codeunit "LSC POS Control Interface";
        POSGUI: Codeunit "LSC POS GUI";
        POSSESSION: Codeunit "LSC POS Session";
        POSTransaction: Codeunit "LSC POS Transaction";
        PosCtrl_g: Codeunit "LSC POS Control Interface";
        PosContext_g: Codeunit "LSC POS Context";
        MontoRecarga_g: code[60];
        NumeroTelefono_g: Text;
        POSTransaction_g: Record "LSC POS Transaction";
        POSTransLine_g: Record "LSC POS Trans. Line";
        POSMenuLine_g: Record "LSC POS Menu Line";
        POSMenuLine_if: Record "LSC POS Menu Line";
        OperadoraTelefonica_g: Record "FSN Operadoras Telefonicas";
        InsertModifyError: Label 'No se ha podido insertar/modificar registro de recarga.';
        VaciosError: Label 'El monto o número de teléfono no deben ser vacios';
        ErrorMonto: Label 'El monto no es válido';
        ErrorNumeroTelefono: Label 'El número de teléfono no es válido';
        RecExitosa: Boolean;
        ItemRecarga: Code[20];
        RecargaElectronica: Record "FSN Recargas Electronicas";
        rRecargasHistorica: Record "FSN Recargas Electr. Hist.";
        BODYGLOBAL: Text;
        NoTelefono: Text;

    /// <summary>
    /// Recuepera valores de la pos transaction y pos trans. line
    /// </summary>
    /// <param name="POSTransaction"></param>
    /// <param name="POSTransLine"></param>
    /// <param name="CurrInput"></param>

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterInsertItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterInsertItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text
    )
    begin
        POSTransaction_g := POSTransaction;
        POSTransLine_g := POSTransLine;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterValidateItemLine', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterValidateItemLine"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var Proceed: Boolean
    )
    var
        lText000: Label 'Solo puede haber una recarga por transaccion.';
        cont: Codeunit "LSC POS Controller";
    begin
        OperadoraTelefonica_g.Reset();
        OperadoraTelefonica_g.SetRange("No. Producto", CurrInput);
        IF OperadoraTelefonica_g.FIND('-') THEN BEGIN
            POSTransLine.reset;
            POSTransLine.SETRANGE(POSTransLine."Receipt No.", POSTransaction."Receipt No.");
            POSTransLine.SETRANGE(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
            POSTransLine.SETRANGE(POSTransLine."Entry Status", 0);
            POSTransLine.SETRANGE(POSTransLine.Number, OperadoraTelefonica_g."No. Producto");
            IF POSTransLine.FindFirst() THEN BEGIN
                POSGUI.PosMessage(lText000);
                Proceed := false;
                CurrInput := '';
            end;
        END;
    end;


    /// <summary>
    /// Sirve para validar si se ha invocado un lookup de recargas telefonicas desde el punto de venta
    /// Invoca panel de ingreso de numero telefonico y validacion de monto
    /// </summary>
    /// <param name="LookupID"></param>
    /// <param name="FilterText"></param>
    /// <param name="resultOK"></param>
    /// <param name="processed"></param>
    ///
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnLookupResult', '', true, true)]
    local procedure "LSC POS Controller_OnLookupResult"
    (
        LookupID: Text;
        FilterText: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        PosInterface: Codeunit "LSC POS Control Interface";
        recRef: RecordRef;
        poscardEntryTmp: Record "LSC POS Card Entry" temporary;
        Price: Decimal;
        cotrol: Codeunit "LSC POS Transaction";
        codP: Code[15];
        mont: Text;
    begin

        if LookupID = 'PAQUETIGO' THEN begin
            POSCtrl.SetInputText('#NUMRECARGA', '');
            codP := PosInterface.GetLookupKeyValue(LookupID);
            ValidateNoPaquete(codP, cotrol.GetReceiptNo);
        end;

        if not (LookupID in ['PNTMONTOSCLA', 'PNTMONTOSDIG', 'PNTMONTOSTEL', 'PNTMONTOSTIG']) then begin
            exit;
        end else begin
            POSCtrl.SetInputText('#NUMRECARGA', '');
            OperadoraTelefonica_g.Reset();
            OperadoraTelefonica_g.SetRange("No. Producto", POSTransLine_g.Number);
            IF OperadoraTelefonica_g.FindFirst() THEN BEGIN
                MontoRecarga_g := PosInterface.GetLookupKeyValue(LookupID);
                if resultOK then begin
                    ShowPanel(MontoRecarga_g, POSTransLine_g.Number, POSTransaction_g."Receipt No.");
                end else begin
                    processed := FALSE;
                    POSTransaction.VoidLinePressed;
                end;
            END ELSE begin
                processed := FALSE;
            end;
        end;
    end;

    /// <summary>
    /// Valida si el panel es RECARGA recupera el nuemor de lefono y monto del panel
    /// Evalua el monto y numero de telefono para insertar un registro en la tabla FSN Recargas Electronicas
    /// </summary>
    /// <param name="panelID"></param>
    /// <param name="resultOK"></param>
    /// <param name="payload"></param>
    /// <param name="processed"></param>
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnModalPanelResult', '', true, true)]
    local procedure "LSC POS Controller_OnModalPanelResult"
       (
           panelID: Text;
           resultOK: Boolean;
           payload: Text;
           var processed: Boolean
       )
    var
        PosInterface: Codeunit "LSC POS Control Interface";
        recRef: RecordRef;
        poscardEntryTmp: Record "LSC POS Card Entry" temporary;
        //numeroTel: Text;
        //montoRecarga: Text;
        recargasElectronicas: Record "FSN Recargas Electronicas";
        NumeroTelefono: Text;
        MontoARecargar: Decimal;
        POSTransCode: Codeunit "LSC POS Transaction";
    begin
        if not ((panelID = '#RECARGA') and (payload = '#RECARGADATA')) then
            exit;

        NumeroTelefono_g := PosInterface.GetInputText('#NUMRECARGA');
        MontoRecarga_g := PosContext_g.GetValue('<#MONTORECARGA>');

        IF (NumeroTelefono_g <> '') and (MontoRecarga_g <> '') then begin

            IF EVALUATE(NumeroTelefono, NumeroTelefono_g) THEN BEGIN
                IF EVALUATE(MontoARecargar, MontoRecarga_g) THEN BEGIN
                    IF NOT SetHistoricoRecargas(POSTransaction_g, POSTransLine_g, MontoARecargar, OperadoraTelefonica_g.Nombre, NumeroTelefono, '', '', '', 0, '') THEN
                        POSCtrl.PosMessage(InsertModifyError);
                END ELSE BEGIN
                    POSGUI.PosMessage(ErrorMonto);
                END;
            END ELSE BEGIN
                POSGUI.PosMessage(ErrorNumeroTelefono);
            END;
        END ELSE BEGIN
            POSGUI.PosMessage(VaciosError);
            POSTransCode.CancelPressed(true, 0);
            POSTransCode.VoidLinePressed;
            exit;
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeTransactionTendered', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeTransactionTendered"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var TenderType: Record "LSC Tender Type";
        var VoidInProcess: Boolean;
        var Balance: Decimal
    )
    var
        WSResponse: Text;
        NumeroTelefono: Text;
        MontoARecargar: Decimal;
        POSTransCod: Codeunit "LSC POS Transaction";
        POSTransLine: Record "LSC POS Trans. Line";
        RecargaH: Record "FSN Recargas Electr. Hist.";
        lText000: Label 'La recarga no fue exitosa: anule la transaccion';
        lText001: Label 'La transaccion actual ya existe en Historico de Recarga, anule la transaccion';
    begin
        RecargaH.Reset;
        RecargaH.SetRange("Receipt No.", POSTransaction."Receipt No.");
        if RecargaH.FindFirst then begin
            OperadoraTelefonica_g.Reset();
            OperadoraTelefonica_g.SetRange(Nombre, RecargaH.Operador);
            IF OperadoraTelefonica_g.FindFirst() THEN BEGIN
                IF OperadoraTelefonica_g.Nombre <> 'PaqueTigo' THEN BEGIN
                    ItemRecarga := POSTransLine_g.Number;
                    IF (NumeroTelefono_g <> '') and (MontoRecarga_g <> '') then begin
                        IF EVALUATE(NumeroTelefono, NumeroTelefono_g) THEN BEGIN
                            IF EVALUATE(MontoARecargar, MontoRecarga_g) THEN BEGIN
                                RecargaElectronica.RESET;
                                RecargaElectronica.SETRANGE("Store No.", PosTransaction."Store No.");
                                RecargaElectronica.SETRANGE("POS Terminal No.", PosTransaction."POS Terminal No.");
                                RecargaElectronica.SetRange("Receipt No.", POSTransaction_g."Receipt No.");
                                IF NOT RecargaElectronica.FindLast() THEN BEGIN
                                    WSResponse := RecargaElectronicaWS(NumeroTelefono, MontoARecargar, POSTransaction_g, 0, OperadoraTelefonica_g.Nombre);
                                    if (WSResponse <> 'OK') then begin
                                        VoidInProcess := true;
                                        POSTransLine.reset;
                                        POSTransLine.setrange(POSTransLine."Receipt No.", POSTransaction."Receipt No.");
                                        if POSTransLine.Find('-') then begin
                                            repeat
                                                POSTransLine.VoidLine();
                                            UNTIL POSTransLine.NEXT = 0;
                                        end;
                                        exit;
                                    end;
                                end;
                            END ELSE BEGIN
                                Error(ErrorMonto);
                            END;
                        END ELSE BEGIN
                            Error(ErrorNumeroTelefono);
                        END;
                    END ELSE BEGIN
                        Error(VaciosError);
                        POSTransCod.CancelPressed(true, 0);
                        POSTransCod.VoidLinePressed;
                        exit;
                    END;
                END ELSE begin
                    IF not (RecargaH.Observacion in ['0', 'COMODIN']) THEN begin
                        POSGUI.PosMessage(lText000);
                        VoidInProcess := true;
                        POSTransLine.reset;
                        POSTransLine.setrange(POSTransLine."Receipt No.", POSTransaction."Receipt No.");
                        if POSTransLine.Find('-') then begin
                            repeat
                                POSTransLine.VoidLine();
                            UNTIL POSTransLine.NEXT = 0;
                        end;
                        exit;
                    end;
                end;
            END;
        end;
    end;



    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'ProcessTransactionOnAfterWriteToDB', '', true, true)]
    local procedure "LSC POS Post Utility_ProcessTransactionOnAfterWriteToDB"(POSTransaction: Record "LSC POS Transaction")
    var
        transHeader: Record "LSC Transaction Header";
        RecargaElect: Record "FSN Recargas Electronicas";
        PosInterface: Codeunit "LSC POS Control Interface";
        HistoricoRecarga: Record "FSN Recargas Electr. Hist.";
    begin
        transHeader.SetRange("Receipt No.", POSTransaction."Receipt No.");
        transHeader.FindFirst();

        if (ItemRecarga <> '') and not POSTransaction."Sale Is Return Sale" THEN BEGIN
            RecargaElect.Reset();
            RecargaElect.SetRange("Receipt No.", POSTransaction."Receipt No.");
            IF RecargaElect.FindLast() THEN BEGIN
                RecargaElect."Transaction No." := transHeader."Transaction No.";
                if not RecargaElect.Modify() then
                    POSGUI.PosMessage('RecargaElect: Modificacion fallida');
            END;

            HistoricoRecarga.Reset();
            HistoricoRecarga.SetRange("Receipt No.", POSTransaction."Receipt No.");
            HistoricoRecarga.SetRange("POS Terminal No.", POSTransaction."POS Terminal No.");
            HistoricoRecarga.SetRange("Store No.", POSTransaction."Store No.");
            if HistoricoRecarga.FindLast() then begin
                HistoricoRecarga."Transaction No." := transHeader."Transaction No.";
                if not HistoricoRecarga.Modify() then
                    POSGUI.PosMessage('HistoricoRecarga: Modificacion fallida');
                PosInterface.SetInputText('#NUMRECARGA', '');
            end;

            Clear(ItemRecarga);
            Clear(RecargaElect);
            Clear(HistoricoRecarga);
            Clear(MontoRecarga_g);
            Clear(NumeroTelefono_g);
            Clear(POSTransaction_g);
            Clear(POSTransLine_g);
            Clear(RecargaElectronica);

        END;
    end;

    procedure RecargaElectronicaWS(telefono: Text[15]; monto: Decimal; PosTransaction: Record "LSC POS Transaction"; transactionNo: Integer; operador: Text) vResultado: Text[250]
    var
        xml: Text[250];
        url: Text[250];
        soapActionUrl: Text[100];
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        ascii: DotNet Encoding;
        credentials: DotNet CredentialCache;
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        xmlelement: DotNet XmlElement;
        tmonto: Text[15];
        rRecargasElectronicasHistoricas: Record "FSN Recargas Electr. Hist.";
        i: Integer;
        cadena: Text[250];
        nodos: Integer;
        RecargasElectronicas_l: Record "FSN Recargas Electronicas";
        vMontoAcreditado: Decimal;
        vMontoDisponible: Decimal;
        rTransactionHeader: Record "LSC Transaction Header";
        vTransaccion: Text[50];
        vSucursal: Text[50];
        vSucursalCajaTicketClaro: Text[50];
        vSucursalCajaTicketDigicel: Text[50];
        rRespuestasOperadores: Record "FSN Respuestas Operadoras";
        vPosTransaccionOperador: Integer;
        vPosTransaccionOperadorFin: Integer;
        vPosMonto: Integer;
        vPosEstado: Integer;
        xmlFinal: File;
        xmlStream: OutStream;
        WSResponse: Text;
        WSMonto: Text;
        Index: Integer;
        WSIdTransaction: Text;
        WSBalance: Text;
        Doc: XmlDocument;
        Node: XmlNode;
        NewNode: XmlElement;
        Options: XmlReadOptions;
        Result: Text;
        XmlString: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        WSConexionOperador: Codeunit "FSN WSConexion";
        POSMenuLineTempR: Record "LSC POS Menu Line" temporary;
        Repons: Text;
        lText001: Label 'Error en repuesta WS, debe Anular la Transaccion';
        lText002: Label 'Respuesta del Operador fallo, debe Anular Transaccion\%1';
        lText003: Label 'Respuesta del Operador exitosa.';
        lText004: Label 'Recarga de COMODIN exitosa.';
    begin
        clear(Repons);
        clear(WSIdTransaction);
        clear(WSResponse);
        clear(WSMonto);
        clear(WSBalance);
        RecExitosa := false;
        vTransaccion := FORMAT(transactionNo);
        vSucursal := DELCHR(COPYSTR(PosTransaction."Store No.", 2, 3) + COPYSTR(PosTransaction."POS Terminal No.", 4, 3), '=', ' ');
        vSucursalCajaTicketClaro := DELCHR(COPYSTR(PosTransaction."Receipt No.", 8, 19), '=', ' ');
        vSucursalCajaTicketDigicel := DELCHR(COPYSTR(PosTransaction."Receipt No.", 8, 19), '=', ' ');
        vSucursalCajaTicketDigicel := DELCHR(CONVERTSTR(COPYSTR(PosTransaction."Receipt No.", 8, 19), '#', '0'), '=', ' ');

        IF telefono <> '77777' THEN BEGIN
            CASE operador OF
                'Claro':
                    BEGIN
                        nodos := 6;
                        xml := '<RecargaClaroNew xmlns="http://tempuri.org/">' +
                                  '<telefono>' + telefono + '</telefono>' +
                                  '<monto>' + FORMAT(monto) + '</monto>' +
                                  '<transaccion>' + vSucursalCajaTicketClaro + '</transaccion>' +
                                '</RecargaClaroNew>';
                        url := 'http://192.168.0.234:1922/WebServices.asmx?op=RecargaClaroNew';
                        soapActionUrl := '"http://tempuri.org/RecargaClaroNew"';
                    END;
                'Digicel':
                    BEGIN
                        nodos := 8;
                        xml := '<RecargaDigicel xmlns="http://tempuri.org/">' +
                                  '<telefono>' + telefono + '</telefono>' +
                                  '<monto>' + FORMAT(monto) + '</monto>' +
                                  '<sucursalcajaticket>' + vSucursalCajaTicketDigicel + '</sucursalcajaticket>' +
                                '</RecargaDigicel>';
                        url := 'http://192.168.0.234:1919/WebServices.asmx?op=RecargaDigicel';
                        soapActionUrl := '"http://tempuri.org/RecargaDigicel"';
                    END;
                'Telefonica':
                    BEGIN
                        nodos := 8;
                        xml := '<RecargaTelefonica xmlns="http://tempuri.org/">' +
                                  '<telefono>' + telefono + '</telefono>' +
                                  '<monto>' + FORMAT(monto) + '</monto>' +
                                '</RecargaTelefonica>';
                        url := 'http://192.168.0.234:1919/WebServices.asmx?op=RecargaTelefonica';
                        soapActionUrl := '"http://tempuri.org/RecargaTelefonica"';
                    END;

                'Tigo':
                    BEGIN
                        //CSPNT211216
                        nodos := 8;
                        xml := '<RecargaTigo xmlns="http://tempuri.org/">' +
                                  '<telefono>' + telefono + '</telefono>' +
                                  '<monto>' + FORMAT(monto) + '</monto>' +
                                  '<sucursal>' + PosTransaction."Store No." + '</sucursal>' +
                                '<transaccion>' + DelChr(PosTransaction."Receipt No.", '=', '#') + '</transaccion>' +
                                '</RecargaTigo>';
                        url := 'http://192.168.0.234:1920/WebServices.asmx?op=RecargaTigo';
                        soapActionUrl := '"http://tempuri.org/RecargaTigo"';
                    END;
            END;

            CLEAR(POSMenuLineTempR);
            POSMenuLineTempR.INIT;
            POSMenuLineTempR.Command := 'WSRECARGA';
            POSMenuLineTempR.Parameter := operador;
            POSMenuLineTempR."Current-RECEIPT" := FORMAT(PosTransaction."Receipt No.");
            POSMenuLineTempR."Called from Codeunit" := telefono;
            POSMenuLineTempR."Registration Mode" := TRUE;
            POSMenuLineTempR."Current-GUEST" := nodos;
            POSMenuLineTempR."Current-Message" := url;
            POSMenuLineTempR."Set Current-Input" := soapActionUrl;
            WSConexionOperador.SetBodyGlobal(FORMAT(xml));
            COMMIT;
            IF WSConexionOperador.RUN(POSMenuLineTempR) THEN BEGIN
                Repons := WSConexionOperador.GetResponseGlobals();
                WSIdTransaction := WSConexionOperador.WSIdTransactionGlobalR;
                WSResponse := WSConexionOperador.WSResponseGlobalR();
                WSMonto := WSConexionOperador.WSMontoGlobalR;
                WSBalance := WSConexionOperador.WSBalanceGlobalR();
                RecExitosa := WSConexionOperador.RecExitosaGlobalR();
            END ELSE begin
                POSCtrl.PosMessage(GetLastErrorText());
                vResultado := '';
            end;
            IF RecExitosa THEN BEGIN
                vResultado := 'OK';
                SetHistoricoRecargas(PosTransaction, POSTransLine_g, monto, operador, telefono, WSIdTransaction, '0', WSMonto, vMontoAcreditado, WSBalance);
                SetRecargaTelefonica(PosTransaction, POSTransLine_g, monto, operador, telefono, WSIdTransaction, '0', WSMonto, vMontoAcreditado, WSBalance, POSTransLine_g."Line No.");
                POSCtrl.PosMessage(lText003);
            END
            ELSE BEGIN
                vResultado := WSResponse;
                if Repons = '' then
                    POSCtrl.PosMessage(lText001)
                else
                    POSCtrl.PosMessage(StrSubstNo(lText002, vResultado));

                SetHistoricoRecargas(PosTransaction, POSTransLine_g, monto, operador, telefono, WSIdTransaction, WSResponse, WSMonto, vMontoAcreditado, WSBalance);
                Commit();
            END;
            /*olopez reader.Close();
             str.Close(); olopez*/
        END
        ELSE BEGIN
            //RECARGA COMODIN
            RecargasElectronicas_l.INIT;
            RecargasElectronicas_l."Line No." := POSTransLine_g."Line No.";
            RecargasElectronicas_l."Store No." := PosTransaction."Store No.";
            RecargasElectronicas_l."POS Terminal No." := PosTransaction."POS Terminal No.";
            RecargasElectronicas_l."Receipt No." := PosTransaction."Receipt No.";
            RecargasElectronicas_l."Staff ID" := PosTransaction."Staff ID";
            RecargasElectronicas_l."Numero Telefono" := telefono;
            RecargasElectronicas_l."Monto Recarga" := monto;
            RecargasElectronicas_l.Operador := operador;
            RecargasElectronicas_l.Fecha := PosTransaction."Trans. Date";
            RecargasElectronicas_l.Hora := PosTransaction."Trans Time";
            RecargasElectronicas_l."Fecha Recarga" := CURRENTDATETIME;
            RecargasElectronicas_l."Transaccion Operador" := 'COMODIN';
            RecargasElectronicas_l."Respuesta Servicio" := '77777';
            EVALUATE(vMontoAcreditado, FORMAT(monto));
            RecargasElectronicas_l."Monto Acreditado" := vMontoAcreditado;
            RecargasElectronicas_l.CESC := ROUND(ROUND(vMontoAcreditado / 1.18, 0.01) * 0.05, 0.01);
            EVALUATE(vMontoDisponible, FORMAT(0));
            RecargasElectronicas_l."Monto Disponible" := vMontoDisponible;
            IF RecargasElectronicas_l.INSERT(true) THEN BEGIN
                Database.COMMIT();
            END;
            vResultado := 'OK';
            //POSCtrl.PosMessage('Recarga COMODIN exitosa.');
        END;
    END;

    procedure SetRecargaTelefonica(var Trasaction_l: Record "LSC POS Transaction"; var TransLine_l: Record "LSC POS Trans. Line"; Amount: Decimal; Operador: Text; Telefono: Text; WSIdTransaction: text; WSResponse: text; WSMonto: text; vMontoAcreditado: Decimal; vMontoDisponible: Text; LineNo: Integer): Boolean
    var
        numTel: Integer;
        montoRec: Decimal;
        montoDisponible: Decimal;
        montoAcreditado: Decimal;
        MontosOperadoras: Record "FSN Montos Operadoras";
        OperadoraTelefonica: Decimal;
        MontoARecargar: Decimal;
        POSTransLineFilt: Record "LSC POS Trans. Line";
    begin
        RecargaElectronica.RESET;
        RecargaElectronica.SETRANGE("Store No.", Trasaction_l."Store No.");
        RecargaElectronica.SETRANGE("POS Terminal No.", Trasaction_l."POS Terminal No.");
        RecargaElectronica.SetRange("Receipt No.", POSTransaction_g."Receipt No.");

        IF NOT RecargaElectronica.FIND('-') THEN BEGIN
            RecargaElectronica.INIT;
            RecargaElectronica."Line No." := LineNo;
            RecargaElectronica."Store No." := Trasaction_l."Store No.";
            RecargaElectronica."POS Terminal No." := Trasaction_l."POS Terminal No.";
            RecargaElectronica."Receipt No." := Trasaction_l."Receipt No.";
            RecargaElectronica."Staff ID" := Trasaction_l."Staff ID";
            RecargaElectronica."Numero Telefono" := telefono;
            RecargaElectronica."Monto Recarga" := Amount;
            RecargaElectronica.Operador := operador;
            RecargaElectronica.Fecha := Trasaction_l."Trans. Date";
            RecargaElectronica.Hora := Trasaction_l."Trans Time";
            RecargaElectronica."Fecha Recarga" := CURRENTDATETIME;
            RecargaElectronica."Transaccion Operador" := WSIdTransaction;
            RecargaElectronica."Respuesta Servicio" := WSResponse;
            EVALUATE(montoAcreditado, WSMonto);
            RecargaElectronica."Monto Acreditado" := montoAcreditado;
            RecargaElectronica.CESC := ROUND(ROUND(montoAcreditado / 1.18, 0.01) * 0.05, 0.01);
            EVALUATE(montoDisponible, vMontoDisponible);
            RecargaElectronica."Monto Disponible" := montoDisponible;
            IF RecargaElectronica.INSERT(true) THEN BEGIN
                Database.COMMIT();
            END ELSE BEGIN
                EXIT(FALSE);
            END;
        END;



        EXIT(true);
    end;

    procedure SetHistoricoRecargas(var Trasaction_l: Record "LSC POS Transaction"; var TransLine_l: Record "LSC POS Trans. Line"; Amount: Decimal; Operador: Text; Telefono: Text; WSIdTransaction: text; WSResponse: text; WSMonto: text; vMontoAcreditado: Decimal; vMontoDisponible: Text): Boolean
    var
        numTel: Integer;
        montoRec: Decimal;
        RecargaFallida: Record "FSN Recargas Electr. Hist.";
        MontosOperadoras: Record "FSN Montos Operadoras";
        MontoARecargar: Decimal;
        POSTransLineFilt: Record "LSC POS Trans. Line";
    begin
        RecargaFallida.Reset();
        RecargaFallida.SetCurrentKey("Store No.", "POS Terminal No.", "Receipt No.");
        RecargaFallida.SETRANGE("Store No.", Trasaction_l."Store No.");
        RecargaFallida.SETRANGE("POS Terminal No.", Trasaction_l."POS Terminal No.");
        RecargaFallida.SETRANGE("Receipt No.", Trasaction_l."Receipt No.");

        if not (RecargaFallida.FindLast()) then begin
            RecargaFallida.init;
            RecargaFallida."Intento No." := 1;
            RecargaFallida.Reset();
            RecargaFallida."Line No." := POSTransLine_g."Line No.";
            RecargaFallida."Store No." := Trasaction_l."Store No.";
            RecargaFallida."POS Terminal No." := Trasaction_l."POS Terminal No.";
            RecargaFallida."Receipt No." := Trasaction_l."Receipt No.";
            RecargaFallida."Intento No." := RecargaFallida."Intento No.";
            RecargaFallida."Staff ID" := Trasaction_l."Staff ID";
            RecargaFallida."Numero Telefono" := FORMAT(Telefono);
            RecargaFallida."Monto Recarga" := Amount;
            RecargaFallida.Operador := Operador;
            RecargaFallida.Fecha := TODAY;
            RecargaFallida.Hora := TIME;
            RecargaFallida."Fecha Recarga" := CURRENTDATETIME();
            IF Telefono <> '77777' THEN
                RecargaFallida.Observacion := WSResponse
            ELSE
                //Obteniendo linea de recarga
                POSTransLine_g.SetRange("Receipt No.", POSTransaction_g."Receipt No.");
            POSTransLine_g.SetRange("Store No.", POSTransaction_g."Store No.");
            POSTransLine_g.SetRange("POS Terminal No.", POSTransaction_g."POS Terminal No.");
            POSTransLine_g.SetRange(Number, ItemRecarga);

            //Onteinedo cantidad de epines
            MontosOperadoras.Init();
            Evaluate(MontoARecargar, MontoRecarga_g);
            MontosOperadoras.SetRange(Monto, MontoARecargar);
            MontosOperadoras.SetRange(Operador, OperadoraTelefonica_g.Nombre);

            if MontosOperadoras.FindFirst() then
                MontoARecargar := MontosOperadoras.Epines;

            //Modificicando el valor de cantidad en la pos trans line por cantidad de epines
            POSTransLineFilt.RESET;//REVISAR
            POSTransLineFilt.SETRANGE(POSTransLineFilt."Receipt No.", POSTransLine_g."Receipt No.");
            POSTransLineFilt.SETRANGE(POSTransLineFilt."Entry Type", POSTransLineFilt."Entry Type"::Item);
            POSTransLineFilt.SETRANGE(POSTransLineFilt."Entry Status", 0);
            POSTransLineFilt.SETRANGE(POSTransLineFilt.Number, POSTransLine_g.Number);
            if POSTransLineFilt.FindFirst() then begin
                POSTransLineFilt.RESET;
                POSTransLineFilt.VALIDATE(Quantity, MontoARecargar);
                POSTransLineFilt.MODIFY(TRUE);
            end;

            if RecargaFallida.INSERT(true) then begin
                Database.COMMIT;
            end else begin
                exit(false);
            end;
        end else begin
            RecargaFallida."Intento No." := RecargaFallida."Intento No." + 1;
            RecargaFallida.Reset();
            RecargaFallida."Line No." := POSTransLine_g."Line No.";
            RecargaFallida."Store No." := Trasaction_l."Store No.";
            RecargaFallida."POS Terminal No." := Trasaction_l."POS Terminal No.";
            RecargaFallida."Receipt No." := Trasaction_l."Receipt No.";
            RecargaFallida."Intento No." := RecargaFallida."Intento No.";
            RecargaFallida."Staff ID" := Trasaction_l."Staff ID";
            RecargaFallida."Numero Telefono" := FORMAT(Telefono);
            RecargaFallida."Monto Recarga" := Amount;
            RecargaFallida.Operador := Operador;
            RecargaFallida.Fecha := TODAY;
            RecargaFallida.Hora := TIME;
            RecargaFallida."Fecha Recarga" := CURRENTDATETIME();
            RecargaFallida.Observacion := WSResponse;
            IF RecargaFallida.Modify(true) THEN BEGIN
                Database.COMMIT;
            END ELSE BEGIN
                EXIT(FALSE);
            END;

            //Onteinedo cantidad de epines
            MontosOperadoras.Init();
            Evaluate(MontoARecargar, MontoRecarga_g);
            MontosOperadoras.SetRange(Monto, MontoARecargar);
            MontosOperadoras.SetRange(Operador, OperadoraTelefonica_g.Nombre);

            if MontosOperadoras.FindFirst() then
                MontoARecargar := MontosOperadoras.Epines;

            //Modificicando el valor de cantidad en la pos trans line por cantidad de epines
            POSTransLineFilt.RESET;//REVISAR
            POSTransLineFilt.SETRANGE(POSTransLineFilt."Receipt No.", POSTransLine_g."Receipt No.");
            POSTransLineFilt.SETRANGE(POSTransLineFilt."Entry Type", POSTransLineFilt."Entry Type"::Item);
            POSTransLineFilt.SETRANGE(POSTransLineFilt."Entry Status", 0);
            POSTransLineFilt.SETRANGE(POSTransLineFilt.Number, POSTransLine_g.Number);
            if POSTransLineFilt.FindFirst() then begin
                POSTransLineFilt.RESET;
                POSTransLineFilt.VALIDATE(Quantity, MontoARecargar);
                POSTransLineFilt.MODIFY(TRUE);
            end;
        end;
        exit(true);
    end;

    procedure ConsultaSaldo(operador: Text) vResultado: Text[250]
    var
        xml: Text[250];
        url: Text[250];
        soapActionUrl: Text[250];
        sb: DotNet StringBuilder;
        uriObj: DotNet Uri;
        lgRequest: DotNet HttpWebRequest;
        stream: DotNet StreamWriter;
        lgResponse: DotNet HttpWebResponse;
        str: DotNet Stream;
        reader: DotNet XmlTextReader;
        document: DotNet XmlDocument;
        ascii: DotNet Encoding;
        credentials: DotNet CredentialCache;
        xmlnodelist: DotNet XmlNodeList;
        xmlnode: DotNet XmlNode;
        xmlelement: DotNet XmlElement;
        tmonto: Text[15];
        rRecargasElectronicasHistoricas: Record "FSN Recargas Electr. Hist.";
        i: Integer;
        cadena: Text[250];
        nodos: Integer;
        rRecargasElectronicas: Record "FSN Recargas Electronicas";
        vMontoAcreditado: Decimal;
        vMontoDisponible: Decimal;
    begin

        CASE operador OF
            '1':
                BEGIN
                    xml := '<ConsultaSaldoClaroNew xmlns="http://tempuri.org/" />';
                    url := 'http://192.168.0.234:1922/WebServices.asmx?op=ConsultaSaldoClaroNew';
                    soapActionUrl := '"http://tempuri.org/ConsultaSaldoClaroNew"';
                END;
            '2':
                BEGIN
                    xml := '<ConsultaSaldoDigicel xmlns="http://tempuri.org/" />';
                    url := 'http://192.168.0.234:1919/WebServices.asmx?op=ConsultaSaldoDigicel';
                    soapActionUrl := '"http://tempuri.org/ConsultaSaldoDigicel"';
                END;
            '3':
                BEGIN
                    xml := '<ConsultaSaldoTelefonica xmlns="http://tempuri.org/" />';
                    url := 'http://192.168.0.234:1919/WebServices.asmx?op=ConsultaSaldoTelefonica';
                    soapActionUrl := '"http://tempuri.org/ConsultaSaldoTelefonica"';
                END;
            '4':
                BEGIN
                    xml := '<ConsultaSaldoTigo xmlns="http://tempuri.org/" />';
                    url := 'http://192.168.0.234:1920/WebServices.asmx?op=ConsultaSaldoTigo';
                    soapActionUrl := '"http://tempuri.org/ConsultaSaldoTigo"';
                END;
        END;

        sb := sb.StringBuilder();
        sb.Append('<?xml version="1.0" encoding="utf-8"?><soap:Envelope ' +
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body>');
        sb.Append(xml);
        sb.Append('</soap:Body></soap:Envelope>');
        uriObj := uriObj.Uri(url);
        lgRequest := lgRequest.CreateDefault(uriObj);
        lgRequest.Method := 'POST';
        lgRequest.ContentType := 'text/xml; charset=utf-8';
        lgRequest.Headers.Add('SOAPAction', soapActionUrl);
        lgRequest.Timeout := 30000;
        stream := stream.StreamWriter(lgRequest.GetRequestStream(), ascii.UTF8);
        stream.Write(sb.ToString());
        stream.Close();
        lgResponse := lgRequest.GetResponse();
        str := lgResponse.GetResponseStream();
        reader := reader.XmlTextReader(str);
        document := document.XmlDocument();
        document.Load(reader);
        xmlnodelist := document.SelectNodes('//*');

        nodos := xmlnodelist.Count;

        IF (nodos = 4) THEN BEGIN
            vResultado := xmlnodelist.Item(3).FirstChild.InnerText;
            POSCtrl.PosMessage('Saldo disponible: \ $ ' + xmlnodelist.Item(3).FirstChild.InnerText);
        END
        ELSE BEGIN
            POSGUI.PosMessage('Respuesta de servicio desconocida');
            EXIT;
        END;
        reader.Close();
        str.Close();
    end;

    /// <summary>
    /// Muestra el panel de corfirmacion del monto e ingreso de numero telefonico.
    /// </summary>
    /// <param name="Monto">Recibe el monto seleccionado del panel monto recargas</param>
    procedure ShowPanel(Monto: Text; ProdShow: Code[20]; ReceiptShow: Code[20])
    var
        FuncProfile_g: Record "LSC POS Func. Profile";
        POSTransLineShow: Record "LSC POS Trans. Line";
        Cliente_p: code[20];
        numtel: Text[20];
        montoRec: Decimal;
    begin
        SetMontoRecarga(Monto);
        PosCtrl_g.ShowPanelModal('#RECARGA', '#RECARGADATA');
    end;

    /// <summary>
    /// Agrega el monto seleccionado en el lookup del boton de recargas del punto de venta.
    /// </summary>
    /// <param name="monto">Monto selecionado en panel de montos operadoras</param>
    local procedure SetMontoRecarga(monto: Text)
    var
        DelOrder: Record "LSC Delivery Order";
        RecRefLocal: RecordRef;


    begin
        PosContext_g.SetKeyValue('<#MONTORECARGA>', Format(monto));
        PosCtrl_g.SendContext(PosContext_g);
    end;

    //Valida si ya existe transaccion de recarga para evitar que muestre modal de monto de recarga
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        POSTransPressed: Record "LSC POS Trans. Line";
        POSTransac: Codeunit "LSC POS Transaction";
        HistRecarga: Record "FSN Recargas Electr. Hist.";
        lText001: Label 'La transaccion actual ya existe en Historico de Recarga, desea continuar?';
    begin
        IF POSMenuLine.Command = 'PLU_K' THEN begin
            OperadoraTelefonica_g.Reset;
            OperadoraTelefonica_g.SetRange("No. Producto", POSMenuLine.Parameter);
            IF OperadoraTelefonica_g.FindFirst() THEN BEGIN
                POSTransPressed.reset;
                POSTransPressed.SETRANGE(POSTransPressed."Receipt No.", POSTransac.GetReceiptNo);
                POSTransPressed.SETRANGE(POSTransPressed."Entry Type", POSTransPressed."Entry Type"::Item);
                POSTransPressed.SETRANGE(POSTransPressed."Entry Status", 0);
                IF POSTransPressed.FindFirst() THEN BEGIN
                    OperadoraTelefonica_g.Reset();
                    OperadoraTelefonica_g.SetRange("No. Producto", POSTransPressed.Number);
                    IF OperadoraTelefonica_g.FindFirst() THEN BEGIN
                        handled := true;
                    end;
                end;
            END;
        end;

        IF POSMenuLine.Parameter in ['PNTMONTOSCLA', 'PNTMONTOSTIG', 'PNTMONTOSTEL', 'PNTMONTOSDIG'] THEN begin
            POSTransPressed.reset;
            POSTransPressed.SETRANGE(POSTransPressed."Receipt No.", POSTransac.GetReceiptNo);
            POSTransPressed.SETRANGE(POSTransPressed."Entry Type", POSTransPressed."Entry Type"::Item);
            POSTransPressed.SETRANGE(POSTransPressed."Entry Status", 0);
            IF POSTransPressed.FindFirst() THEN BEGIN
                OperadoraTelefonica_g.Reset();
                OperadoraTelefonica_g.SetRange("No. Producto", POSTransPressed.Number);
                IF OperadoraTelefonica_g.FindFirst() THEN BEGIN
                    if POSTransPressed.Quantity <> 1 then
                        handled := true;
                end;
            end;
        end;

        IF POSMenuLine.Command IN ['VOID', 'VOID_L'] THEN BEGIN
            HistRecarga.reset;
            HistRecarga.SetRange("Receipt No.", POSTransac.GetReceiptNo);
            IF HistRecarga.FindFirst then begin
                if (HistRecarga.Observacion in ['0', 'COMODIN']) then begin
                    IF NOT POSGUI.PosConfirm(lText001, true) THEN
                        handled := true
                    else
                        handled := false;
                end else begin
                    HistRecarga.Observacion := 'Voided';
                    HistRecarga.MODIFY(TRUE);
                end;
            end;
        END;
    end;

    /////////////////////////////////////////////////////////////////////////////////////////////
    //Invoca comando 'P_TIGO'
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSCommand', '', true, true)]
    local procedure "LSC POS Controller_OnPOSCommand"
    (
        var ActivePanel: Record "LSC POS Panel";
        var PosMenuLine: Record "LSC POS Menu Line"
    )
    var
        post: Record "LSC POS Transaction";
        posline: Record "LSC POS Trans. Line";
        TransLine: Record "LSC Trans. Sales Entry";
        hist: Record "FSN Recargas Electr. Hist.";
        histt: Record "FSN Recargas Electronicas";
        histH: Record "LSC Transaction Header";
        payment: Record "LSC Trans. Payment Entry";
        ss: Record "LSC Trans. Infocode Entry";
    begin
        if PosMenuLine.Command = 'P_TIGO' then begin
            SendNoTelefono(POSTransaction.GetReceiptNo());
        end;
    end;

    //Envia No Telefono, receipt y TransactionNo de la ultima transaccion si numero de telfono es correcto.
    procedure SendNoTelefono(Receipt: Code[20])
    var
        Text000: Label 'Numero Teléfono';
        NoTelefono: Text;
        Result: Action;
        POSTransReceipt: Record "LSC POS Transaction";
        PqTigo: Record "LSC POS Menu Line";
        WSRecarga: Codeunit "FSN Recargas Electronicas";
        TransactionH: Record "LSC Transaction Header";
        HistoricaC: Record "FSN Recargas Electr. Hist.";
        Text001: Label 'La Transaccion %1 ya existe en Historico Recarga';
        Text002: Label 'Ingrese Codigo Vendedor';
    begin
        POSTransReceipt.Reset;
        POSTransReceipt.Get(Receipt);
        IF POSTransReceipt."Sales Staff" <> '' THEN BEGIN
            HistoricaC.RESET;
            HistoricaC.SETRANGE("Receipt No.", POSTransReceipt."Receipt No.");
            IF HistoricaC.Find() THEN BEGIN
                POSGUI.PosMessage(STRSUBSTNO(Text001, HistoricaC."Receipt No."));
            END ELSE BEGIN
                POSGUI.OpenNumericKeyboard(Text000, 0, '', 0, 'PTIGO');
            END;
        END ELSE BEGIN
            //POSGUI.PosMessage(Text002);
            EXIT;
        END;
    end;

    //Result procedure SendNoTelefono
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnNumpadResult', '', true, true)]
    local procedure "LSC POS Controller_OnNumpadResult"
    (
        payload: Text;
        inputValue: Text;
        resultOK: Boolean;
        var processed: Boolean
    )
    var
        ValueInt: Integer;
    begin
        if payload = 'PTIGO' THEN BEGIN
            ValueNoTelefono(inputValue);
            processed := true;
        END;
    end;
    //Evalua tipo telefono y envia vasio producto
    procedure ValueNoTelefono(NoTelefonoResult: Text)
    var
        myInt: Integer;
        NoTelInt: Integer;
        TransactionH: Record "LSC Transaction Header";
        UlTransactionNo: Integer;
        Text001: Label 'El numero de telefono %1 no es valido';
    begin
        CLEAR(UlTransactionNo);
        IF (NoTelefonoResult <> '') THEN BEGIN
            IF EVALUATE(NoTelInt, NoTelefonoResult) AND (STRLEN(NoTelefonoResult) = 8) OR (NoTelefonoResult = '77777') THEN BEGIN
                SendNoTelResult(NoTelefonoResult, POSTransaction.GetReceiptNo, UlTransactionNo + 1, '');
            END ELSE BEGIN
                POSGUI.PosMessage(STRSUBSTNO(Text001, NoTelefonoResult));
            END;
        END;
    end;

    //Envia NoTelefono y resibe la repuesta del ws, y se inboca si se guarda de exitoso
    procedure SendNoTelResult(TelefonoP: Text; ReceiptP: Text; TransctinNoP: Integer; ProdPQ: Text)
    var
        PQTextP: Text;
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        WSConexion: Codeunit "FSN WSConexion";
        Repons: Text;
        Historic: Record "FSN Recargas Electr. Hist.";
        lText001: Label 'Error en repuesta WS PaqueTigo';
        lText002: Label 'Error de paquete, debe realizar anulacion';
        lText003: Label 'No existe parametro varios PAQUETIGOP';
        Parameter: Record "FSN Parameter";
    begin
        Parameter.Reset();
        Parameter.SetRange(Parameter.Grupo, 'POS');
        Parameter.SetRange(Parameter.Codigo, 'PAQUETIGOP');
        IF Parameter.FindFirst() then begin
            PQTextP := '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' +
            'xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<getCatalogPT xmlns="http://tempuri.org/">' +
            '<telefono>' + TelefonoP + '</telefono>' +
            '<ip>' + Parameter.IP + '</ip>' +
            '<pin>9264</pin>' +
            '<tipoConsulta>9</tipoConsulta>' +
            '<parentMenu>' + Parameter.Valor + '</parentMenu>' +
            '</getCatalogPT>' +
            '</soap:Body>' +
            '</soap:Envelope>';

            CLEAR(POSMenuLineTemp);
            Clear(Repons);
            POSMenuLineTemp.INIT;
            POSMenuLineTemp.Command := 'WSECONEXIONPQ';
            POSMenuLineTemp.Parameter := 'PAQUETIGOP';
            POSMenuLineTemp."Post Parameter" := TelefonoP;
            POSMenuLineTemp."Current-RECEIPT" := ReceiptP;
            POSMenuLineTemp."Key No." := TransctinNoP;
            POSMenuLineTemp."Registration Mode" := TRUE;
            WSConexion.SetBodyGlobal(FORMAT(PQTextP));
            COMMIT;
            IF WSConexion.RUN(POSMenuLineTemp) THEN BEGIN
                Repons := WSConexion.GetResponseGlobals();
                IF Repons <> '' THEN BEGIN
                    InfoPaqueTigo(Repons, ReceiptP, TelefonoP, TransctinNoP, ProdPQ);
                END ELSE BEGIN
                    Historic.RESET;
                    Historic.SETRANGE("Receipt No.", ReceiptP);
                    IF Historic.FINDLAST THEN BEGIN
                        Historic.Observacion := '#ERRORCPQ';
                        Historic.MODIFY(TRUE);
                        POSCtrl.PosMessage(lText002);
                    END ELSE BEGIN
                        POSCtrl.PosMessage(lText001);
                        EXIT;
                    END;
                END;
            END ELSE begin
                POSCtrl.PosMessage(lText001);
            end;
        end else begin
            POSGUI.PosMessage(lText003);
        end;
    end;

    //infocode con paquetes
    procedure InfoPaqueTigo(ValueNode: Text; ReceiptJ: Text; TelefonoJ: Text; TransactNoJ: Integer; PRODPq: Text)
    var
        POSMenuLineTempR: Record "LSC POS Menu Line" temporary;
        POStransR: Record "LSC POS Transaction";
        ODConexion: Codeunit "FSN OData Conexion";
        POSMenuLinePaqR: Record "LSC POS Menu Line" temporary;
        HistoricaR: Record "FSN Recargas Electr. Hist.";
        POSMenuLineInfocodeTmp: Record "LSC POS Menu Line" temporary;
        JObject: DotNet JObject;
        Index: Integer;
        RecRef: RecordRef;
        ResultJToken: Text;
        JTLabelMenu: DotNet JToken;
        JTCodigoProducto: DotNet JToken;
        JTprecioVendedor: DotNet JToken;
        JTmtrLabel: DotNet JToken;
        JTmensajeSalida: DotNet JToken;
        JTmensajeVendedor: DotNet JToken;
        JTclaseSuscripcion: DotNet JToken;
        JTtipoPlan: DotNet JToken;
        JTtipoProducto: DotNet JToken;
        NewJson: Text;
        document: DotNet XmlDocument;
        Convert: DotNet JsonConvert;
        numTel: Integer;
        montoRec: Decimal;
        RecargaP: Text;
        Text000: Label 'El monto: %1  no es valido';
        Text001: Label 'El numero de telefono: %1  no es valido';
        Text002: Label 'Recarga Cancelada, intente nuevamente';
        Text003: Label 'Debe anular la transaccion actual';
        Text004: Label 'Solo puede haber una recarga por transaccion.';
        Text005: Label 'Ya hay una recarga fallida, debe realizar devolución';
        Text006: Label 'Error en repuesta WS Recarga PaqueTigo';
        PQTextR: Text;
        paqueTender: Text;
        PriceTxt: Text;
        rProductPQ: Record "FSN Operadoras Telefonicas";
        OK_: Text;
        WSConexion: Codeunit "FSN WSConexion";
        Repons: Text;
    begin
        clear(Repons);
        POSMenuLineInfocodeTmp.RESET;
        POSMenuLineInfocodeTmp.DELETEALL;
        CLEAR(POSMenuLineInfocodeTmp);
        POSMenuLinePaqR.reset;
        POSMenuLinePaqR.DELETEALL;
        CLEAR(POSMenuLinePaqR);

        JObject := JObject.JObject();
        document := document.XmlDocument();
        document.LoadXml(ValueNode);
        NewJson := Convert.SerializeXmlNode(document);
        JObject := JObject.Parse(NewJson);
        JObject := JObject.SelectToken('soap:Envelope');
        JObject := JObject.SelectToken('soap:Body');
        JObject := JObject.SelectToken('getCatalogPTResponse');
        JObject := JObject.SelectToken('getCatalogPTResult');
        JObject := JObject.SelectToken('dtoGetProductCatalog');
        Index := 1;

        WHILE Index <= JObject.Count() DO BEGIN
            JTLabelMenu := JObject.Item(Index - 1);
            JTCodigoProducto := JObject.Item(Index - 1);
            JTprecioVendedor := JObject.Item(Index - 1);
            JTmtrLabel := JObject.Item(Index - 1);
            JTmensajeSalida := JObject.Item(Index - 1);
            JTmensajeVendedor := JObject.Item(Index - 1);
            JTclaseSuscripcion := JObject.Item(Index - 1);
            JTtipoPlan := JObject.Item(Index - 1);
            JTtipoProducto := JObject.Item(Index - 1);

            JTLabelMenu := JTLabelMenu.SelectToken('labelMenu');
            JTCodigoProducto := JTCodigoProducto.SelectToken('codigoProducto');
            JTprecioVendedor := JTprecioVendedor.SelectToken('precioVendedor');
            JTmtrLabel := JTmtrLabel.SelectToken('mtrLabel');
            JTmensajeSalida := JTmensajeSalida.SelectToken('mensajeSalida');
            JTmensajeVendedor := JTmensajeVendedor.SelectToken('mensajeVendedor');
            JTclaseSuscripcion := JTclaseSuscripcion.SelectToken('claseSuscripcion');
            JTtipoPlan := JTtipoPlan.SelectToken('tipoPlan');
            JTtipoProducto := JTtipoProducto.SelectToken('tipoProducto');

            IF NOT ISNULL(JTCodigoProducto) THEN BEGIN
                IF PRODPq = '' THEN BEGIN
                    POSMenuLineInfocodeTmp.INIT;
                    POSMenuLineInfocodeTmp."Menu ID" := (ODConexion.GetValueAsText(JTCodigoProducto, '#text'));
                    POSMenuLineInfocodeTmp.Description := COPYSTR(ODConexion.GetValueAsText(JTLabelMenu, '#text'), 1, 40);
                    POSMenuLineInfocodeTmp."Current-Price" := (ODConexion.GetValueAsDecimal(JTprecioVendedor, '#text'));
                    POSMenuLineInfocodeTmp.INSERT;

                END ELSE BEGIN
                    IF (ODConexion.GetValueAsText(JTCodigoProducto, '#text')) = PRODPq THEN BEGIN
                        POSMenuLinePaqR.INIT;
                        POSMenuLinePaqR."Menu ID" := (ODConexion.GetValueAsText(JTCodigoProducto, '#text'));
                        POSMenuLinePaqR."Glyph Text" := COPYSTR(ODConexion.GetValueAsText(JTLabelMenu, '#text'), 1, 40);
                        POSMenuLinePaqR."Current-Price" := (ODConexion.GetValueAsDecimal(JTprecioVendedor, '#text'));
                        POSMenuLinePaqR."Glyph Text 2" := (ODConexion.GetValueAsText(JTmtrLabel, '#text'));
                        POSMenuLinePaqR."Current-Message" := (ODConexion.GetValueAsText(JTmensajeSalida, '#text'));

                        IF NOT ISNULL(JTmensajeVendedor) THEN BEGIN
                            POSMenuLinePaqR."Image URI" := (ODConexion.GetValueAsText(JTmensajeVendedor, '#text'));
                        END;

                        POSMenuLinePaqR."Glyph Text 3" := (ODConexion.GetValueAsText(JTclaseSuscripcion, '#text'));
                        POSMenuLinePaqR."Glyph Text 4" := (ODConexion.GetValueAsText(JTtipoPlan, '#text'));
                        POSMenuLinePaqR."POS Action Message" := (ODConexion.GetValueAsText(JTtipoProducto, '#text'));
                        POSMenuLinePaqR.INSERT;
                    end;
                END;
                Index += 1;
            END;
        END;
        HistoricaR.RESET;
        HistoricaR.SETRANGE("Receipt No.", ReceiptJ);
        IF HistoricaR.FINDLAST THEN BEGIN
            IF HistoricaR.Observacion = '0' THEN BEGIN
                POSCtrl.PosMessage(Text004);
                EXIT;
            END ELSE BEGIN
                POSMenuLinePaqR.RESET;
                POSMenuLinePaqR.SETRANGE(POSMenuLinePaqR."Menu ID", HistoricaR.Observacion);
                IF POSMenuLinePaqR.FINDLAST THEN BEGIN
                    rProductPQ.RESET;
                    rProductPQ.SETRANGE(ID, '5');
                    if rProductPQ.FINDFIRST then
                        OK_ := PluPqueTigo(HistoricaR."Receipt No.", HistoricaR."Store No.", HistoricaR."POS Terminal No.", POSMenuLinePaqR."Current-Price", rProductPQ."No. Producto");
                    IF OK_ = 'OK' THEN begin
                        IF TelefonoJ <> '77777' THEN BEGIN
                            HistoricaR.RESET;
                            HistoricaR."Tipo Paquete" := POSMenuLinePaqR."Glyph Text";
                            HistoricaR."Monto Recarga" := POSMenuLinePaqR."Current-Price";
                            HistoricaR.MODIFY(TRUE);

                            PQTextR := '<?xml version="1.0" encoding="utf-8"?>' +
                            '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"' +
                            ' xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                            '<soap:Body>' +
                            '<RecargarPT xmlns="http://tempuri.org/">' +
                            '<telefono>' + TelefonoJ + '</telefono>' +
                            '<salesStaff>' + HistoricaR."Staff ID" + '</salesStaff>' +
                            '<pin>9264</pin>' +
                            '<productId>' + POSMenuLinePaqR."Menu ID" + '</productId>' +
                            '<precioVendedor>' + FORMAT(POSMenuLinePaqR."Current-Price") + '</precioVendedor>' +
                            '<mtrLabel>' + POSMenuLinePaqR."Glyph Text 2" + '</mtrLabel>' +
                            '<mensajeSalida>' + POSMenuLinePaqR."Current-Message" + '</mensajeSalida>' +
                            '<mensajeVendedor>' + POSMenuLinePaqR."Image URI" + '</mensajeVendedor>' +
                            '<claseSuscripcion>' + POSMenuLinePaqR."Glyph Text 3" + '</claseSuscripcion>' +
                            '<tipoPlan>' + POSMenuLinePaqR."Glyph Text 4" + '</tipoPlan>' +
                            '<comisionVendedor>0.00</comisionVendedor>' +
                            '<ip>0</ip>' +
                            '<tipoProducto>' + POSMenuLinePaqR."POS Action Message" + '</tipoProducto>' +
                            '<caja>' + HistoricaR."POS Terminal No." + '</caja>' +
                            '<sucursal>' + HistoricaR."Store No." + '</sucursal>' +
                            '<transaccion>' + HistoricaR."Receipt No." + '</transaccion>' +
                            '</RecargarPT>' +
                            '</soap:Body>' +
                            '</soap:Envelope>';

                            CLEAR(POSMenuLineTempR);
                            POSMenuLineTempR.INIT;
                            POSMenuLineTempR.Command := 'WSECONEXIONPQ';
                            POSMenuLineTempR.Parameter := 'PAQUETIGOR';
                            POSMenuLineTempR."Current-RECEIPT" := FORMAT(HistoricaR."Receipt No.");
                            POSMenuLineTempR."Called from Codeunit" := HistoricaR."Numero Telefono";
                            POSMenuLineTempR."Registration Mode" := TRUE;
                            WSConexion.SetBodyGlobal(FORMAT(PQTextR));
                            COMMIT;
                            IF WSConexion.RUN(POSMenuLineTempR) THEN BEGIN
                                Repons := WSConexion.GetResponseGlobals();
                                IF Repons <> '' THEN BEGIN
                                    RecargaPaquete(POSMenuLineTempR, Repons);
                                END ELSE begin
                                    RecargaPaquete(POSMenuLineTempR, '');
                                end;
                            END else begin
                                RecargaPaquete(POSMenuLineTempR, '');
                            end;
                        end ELSE begin
                            ComodinPQ(HistoricaR."Receipt No.");
                        end;
                    end;
                END ELSE BEGIN
                    POSTransaction.CancelPressed(TRUE, 0);
                    POSTransaction.VoidLinePressed;
                    POSCtrl.PosMessage(Text005);
                    EXIT;
                END;
            END;
        END ELSE BEGIN
            IF POStransR.GET(ReceiptJ) THEN BEGIN
                RecRef.GETTABLE(POSMenuLineInfocodeTmp);
                LookUpExResult(RecRef, TelefonoJ);
            END;
        END;
    end;

    //Abre lookup 
    procedure LookUpExResult(RecRefP: RecordRef; Tel: Text) LookupText: text;
    var
        myInt: Integer;
        POSCT: Codeunit "LSC POS Controller";
    begin

        NoTelefono := Tel;
        LookupText := POSTransaction.LookUpEx(true, PQTigoInfocode(), '', RecRefP);
    end;

    procedure PQTigoInfocode(): Text[20]
    begin
        EXIT('PAQUETIGO');
    end;

    //Recibe el result del lookup
    procedure ValidateNoPaquete(CodPaquete: Code[15]; Receipt: Code[20])
    var
        rProductPQ: Record "FSN Operadoras Telefonicas";
        TransactionH: Record "LSC Transaction Header";
        UlTransactionNo: Integer;
    begin
        clear(UlTransactionNo);
        IF CodPaquete <> '' THEN BEGIN
            TransactionH.RESET;
            TransactionH.SetRange("POS Terminal No.", POSSESSION.TerminalNo());
            TransactionH.SetRange("Store No.", POSSESSION.StoreNo);
            IF TransactionH.FIND('+') THEN begin
                UlTransactionNo := TransactionH."Transaction No." + 1;
            end else begin
                UlTransactionNo := 1;
            end;
            rProductPQ.RESET;
            rProductPQ.SETRANGE(ID, '5');
            if rProductPQ.FINDFIRST then
                PaqueTigoTender(rProductPQ.Nombre, NoTelefono, UlTransactionNo, CodPaquete, Receipt);
        END ELSE BEGIN
            EXIT;
        END;
    end;

    //Hace insert en Historico de recarga y evalua que no exista la transaccion actual en hisatorico
    procedure PaqueTigoTender(Operador: Text; Telefono: Text; TransactionNoR: Integer; ProdPQ: Text[10]; ReceiptP: Code[20]) ResultTender: Text
    var
        HistoricoR: Record "FSN Recargas Electr. Hist.";
        POSTr: Record "LSC POS Transaction";
        WSResponse: Text;
        TransHeader: Record "LSC Transaction Header";
        lText001: Label 'La transacción actual ya existe en histórico de recarga';
        lText002: Label 'La transacción actual ya existe en Transaction Header';
    begin
        TransHeader.reset;
        TransHeader.SetRange(TransHeader."Store No.", POSSESSION.StoreNo);
        TransHeader.SetRange(TransHeader."POS Terminal No.", POSSESSION.TerminalNo);
        TransHeader.SetRange(TransHeader."Receipt No.", ReceiptP);
        IF NOT TransHeader.FindFirst() THEN BEGIN
            POSTr.SetRange("Store No.", POSSESSION.StoreNo);
            POSTr.SetRange("POS Terminal No.", POSSESSION.TerminalNo);
            POSTr.SetRange("Receipt No.", ReceiptP);//POSSESSION
            IF POSTr.FindFirst THEN BEGIN
                HistoricoR.RESET;
                HistoricoR.SetRange("Store No.", POSSESSION.StoreNo);
                HistoricoR.SetRange("POS Terminal No.", POSSESSION.TerminalNo);
                HistoricoR.SETRANGE("Transaction No.", TransactionNoR);
                IF NOT HistoricoR.FIND('-') THEN BEGIN
                    HistoricoR.INIT;
                    HistoricoR."Transaction No." := TransactionNoR;
                    //HistoricoR."Line No." := 1;
                    HistoricoR."Store No." := POSTr."Store No.";
                    HistoricoR."POS Terminal No." := POSTr."POS Terminal No.";
                    HistoricoR."Receipt No." := ReceiptP;
                    HistoricoR."Staff ID" := POSTr."Staff ID";
                    HistoricoR."Numero Telefono" := FORMAT(Telefono);
                    HistoricoR."Monto Recarga" := 0;
                    HistoricoR.Operador := Operador;
                    HistoricoR.Fecha := TODAY;
                    HistoricoR.Hora := TIME;
                    HistoricoR."Fecha Recarga" := CURRENTDATETIME();
                    HistoricoR.Observacion := ProdPQ;
                    HistoricoR."Tipo Paquete" := '';
                    HistoricoR.INSERT(true);
                    COMMIT;
                    ResultTender := 'OK';
                    SendNoTelResult(Telefono, POSTr."Receipt No.", TransactionNoR, ProdPQ); //enviar false
                END ELSE BEGIN
                    ResultTender := '0';
                    POSGUI.PosMessage(lText001);
                    EXIT;
                end;
            END;
        END ELSE begin
            ResultTender := '0';
            POSGUI.PosMessage(lText002);
            EXIT;
        end;
    end;

    //Agrega el producto de recarga y modifica el monto de recarga
    procedure PluPqueTigo(ReceiptNoPL: Code[20]; StorePL: Text[10]; POSTErminalPL: Text[10]; PricePL: Decimal; ProdPL: Text[10]) ResultTender: Text
    var
        POSTransLineR: Record "LSC POS Trans. Line";
    begin
        POSTransaction.PluKeyPressed(ProdPL);
        POSTransLineR.RESET;
        POSTransLineR.SETRANGE(POSTransLineR."Receipt No.", ReceiptNoPL);
        POSTransLineR.SETRANGE(POSTransLineR."Entry Type", POSTransLineR."Entry Type"::Item);
        POSTransLineR.SETRANGE(POSTransLineR."Entry Status", 0);
        POSTransLineR.SETRANGE(POSTransLineR.Number, ProdPL);
        IF POSTransLineR.FINDFIRST THEN BEGIN
            POSTransLineR.RESET;
            POSTransLineR.VALIDATE(Quantity, PricePL);
            POSTransLineR.MODIFY(TRUE);
            ResultTender := 'OK';
        END;
    end;

    //hace insert en tabla de recarga exitosa si no envia repuesta del WS a procedure ContrlRecarga
    procedure RecargaPaquete(POSMenuLR: Record "LSC POS Menu Line"; ResultRepons: Text)
    var
        PrintConexionR: Codeunit "FSN OData Conexion";
        POSMenuLineTempR: Record "LSC POS Menu Line" temporary;
        WSResponse: Text;
        RecE: Boolean;
        JObjectR: DotNet JObject;
        JObjectM: DotNet JObject;
        documentR: DotNet XmlDocument;
        NewJsonR: Text;
        ConvertR: DotNet JsonConvert;
        IndexR: Integer;
        JTdisplayCode: DotNet JToken;
        JTdisplayDescription: DotNet JToken;
        rRecargasElectronicasR: Record "FSN Recargas Electronicas";
        rRecargaHistorica: Record "FSN Recargas Electr. Hist.";
        POSTransLine: Record "LSC POS Trans. Line";
        lText001: Label 'Respuesta del Operador exitosa';
        lText002: Label 'Respuesta del Operador fallo, debe Anular Transaccion';
    begin
        rRecargaHistorica.Reset();
        rRecargaHistorica.SetRange("Receipt No.", POSMenuLR."Current-RECEIPT");
        IF rRecargaHistorica.FINDFIRST THEN
            IF ResultRepons <> '' THEN BEGIN
                JObjectR := JObjectR.JObject();
                documentR := documentR.XmlDocument();
                documentR.LoadXml(ResultRepons);
                NewJsonR := ConvertR.SerializeXmlNode(documentR);
                JObjectR := JObjectR.Parse(NewJsonR);
                JObjectR := JObjectR.SelectToken('soap:Envelope');
                JObjectR := JObjectR.SelectToken('soap:Body');
                JObjectR := JObjectR.SelectToken('RecargarPTResponse');
                JObjectR := JObjectR.SelectToken('RecargarPTResult');
                JObjectR := JObjectR.SelectToken('displayCode');
                JObjectR := JObjectR.SelectToken('#text');
                IF FORMAT(JObjectR) = '0' THEN BEGIN
                    rRecargasElectronicasR.INIT;
                    rRecargasElectronicasR."Transaction No." := rRecargaHistorica."Transaction No.";
                    //rRecargasElectronicasR."Line No." := 1;
                    rRecargasElectronicasR."Store No." := rRecargaHistorica."Store No.";
                    rRecargasElectronicasR."POS Terminal No." := rRecargaHistorica."POS Terminal No.";
                    rRecargasElectronicasR."Receipt No." := POSMenuLR."Current-RECEIPT";
                    rRecargasElectronicasR."Staff ID" := rRecargaHistorica."Staff ID";
                    rRecargasElectronicasR."Numero Telefono" := rRecargaHistorica."Numero Telefono";
                    rRecargasElectronicasR."Monto Recarga" := rRecargaHistorica."Monto Recarga";
                    rRecargasElectronicasR.Operador := rRecargaHistorica.Operador;
                    rRecargasElectronicasR.Fecha := rRecargaHistorica.Fecha;
                    rRecargasElectronicasR.Hora := rRecargaHistorica.Hora;
                    rRecargasElectronicasR."Fecha Recarga" := CURRENTDATETIME;
                    rRecargasElectronicasR."Transaccion Operador" := Format(rRecargaHistorica."Transaction No.");
                    rRecargasElectronicasR."Respuesta Servicio" := FORMAT(JObjectR);
                    rRecargasElectronicasR."Monto Acreditado" := rRecargaHistorica."Monto Recarga";
                    rRecargasElectronicasR."Tipo Paquete" := rRecargaHistorica."Tipo Paquete";
                    rRecargasElectronicasR.CESC := ROUND(ROUND(rRecargaHistorica."Monto Recarga" / 1.18, 0.01) * 0.05, 0.01);
                    rRecargasElectronicasR.INSERT(TRUE);
                    COMMIT;
                    ContrlRecarga(rRecargaHistorica."Receipt No.", rRecargaHistorica."Store No.", rRecargaHistorica."POS Terminal No.", rRecargaHistorica."Transaction No.", '0');
                    POSCtrl.PosMessage(lText001);
                END ELSE BEGIN
                    ContrlRecarga(rRecargaHistorica."Receipt No.", rRecargaHistorica."Store No.", rRecargaHistorica."POS Terminal No.", rRecargaHistorica."Transaction No.", '#ERRORPQ');
                    POSTransLine.reset;
                    POSTransLine.setrange(POSTransLine."Receipt No.", POSMenuLR."Current-RECEIPT");
                    if POSTransLine.Find('-') then begin
                        repeat
                            POSTransLine.VoidLine();
                        UNTIL POSTransLine.NEXT = 0;
                    end;
                    JObjectR := JObjectR.JObject();
                    documentR := documentR.XmlDocument();
                    documentR.LoadXml(ResultRepons);
                    NewJsonR := ConvertR.SerializeXmlNode(documentR);
                    JObjectR := JObjectR.Parse(NewJsonR);
                    JObjectR := JObjectR.SelectToken('soap:Envelope');
                    JObjectR := JObjectR.SelectToken('soap:Body');
                    JObjectR := JObjectR.SelectToken('RecargarPTResponse');
                    JObjectR := JObjectR.SelectToken('RecargarPTResult');
                    JObjectR := JObjectR.SelectToken('displayDescription');
                    JObjectR := JObjectR.SelectToken('#text');
                    POSCtrl.PosMessage(FORMAT(JObjectR));
                    EXIT;
                END;
            END ELSE BEGIN
                ContrlRecarga(rRecargaHistorica."Receipt No.", rRecargaHistorica."Store No.", rRecargaHistorica."POS Terminal No.", rRecargaHistorica."Transaction No.", '#ERRORWS');
                POSTransLine.reset;
                POSTransLine.setrange(POSTransLine."Receipt No.", POSMenuLR."Current-RECEIPT");
                if POSTransLine.Find('-') then begin
                    repeat
                        POSTransLine.VoidLine();
                    UNTIL POSTransLine.NEXT = 0;
                end;
                POSCtrl.PosMessage(lText002);
            END;
    end;

    //comodin de recarga
    procedure ComodinPQ(ReceiptCPQ: Code[20])
    var
        rRecargasElectronicasR: Record "FSN Recargas Electronicas";
        rRecargaHistorica: Record "FSN Recargas Electr. Hist.";
        lText003: Label 'Recarga COMODIN exitosa.';
    begin
        rRecargaHistorica.Reset();
        rRecargaHistorica.SetRange("Receipt No.", ReceiptCPQ);
        IF rRecargaHistorica.FINDFIRST THEN
            rRecargasElectronicasR.INIT;
        rRecargasElectronicasR."Transaction No." := rRecargaHistorica."Transaction No.";
        //rRecargasElectronicasR."Line No." := 1;
        rRecargasElectronicasR."Store No." := rRecargaHistorica."Store No.";
        rRecargasElectronicasR."POS Terminal No." := rRecargaHistorica."POS Terminal No.";
        rRecargasElectronicasR."Receipt No." := rRecargaHistorica."Receipt No.";
        rRecargasElectronicasR."Staff ID" := rRecargaHistorica."Staff ID";
        rRecargasElectronicasR."Numero Telefono" := rRecargaHistorica."Numero Telefono";
        rRecargasElectronicasR."Monto Recarga" := rRecargaHistorica."Monto Recarga";
        rRecargasElectronicasR.Operador := rRecargaHistorica.Operador;
        rRecargasElectronicasR.Fecha := rRecargaHistorica.Fecha;
        rRecargasElectronicasR.Hora := rRecargaHistorica.Hora;
        rRecargasElectronicasR."Fecha Recarga" := CURRENTDATETIME;
        rRecargasElectronicasR."Transaccion Operador" := 'COMODIN';
        rRecargasElectronicasR."Respuesta Servicio" := '77777';
        rRecargasElectronicasR."Monto Acreditado" := rRecargaHistorica."Monto Recarga";
        rRecargasElectronicasR."Tipo Paquete" := rRecargaHistorica."Tipo Paquete";
        rRecargasElectronicasR.CESC := ROUND(ROUND(rRecargaHistorica."Monto Recarga" / 1.18, 0.01) * 0.05, 0.01);
        rRecargasElectronicasR.INSERT(TRUE);
        COMMIT;
        ContrlRecarga(rRecargaHistorica."Receipt No.", rRecargaHistorica."Store No.", rRecargaHistorica."POS Terminal No.", rRecargaHistorica."Transaction No.", 'COMODIN');
        POSCtrl.PosMessage(lText003);
    end;

    //Modifica la linea con la repuesta del WS
    procedure ContrlRecarga(CReceipt: code[20]; CStore: Code[10]; CTerminalNo: Code[20]; CTransNo: integer; CResult: Text)
    var
        HistoricaR: Record "FSN Recargas Electr. Hist.";
    begin
        HistoricaR.RESET;
        HistoricaR.SETRANGE("Receipt No.", CReceipt);
        IF HistoricaR.FINDLAST THEN BEGIN
            HistoricaR.RESET;
            HistoricaR.SETRANGE("Store No.", CStore);
            HistoricaR.SETRANGE("POS Terminal No.", CTerminalNo);
            HistoricaR.SETRANGE("Transaction No.", CTransNo);
            HistoricaR.Observacion := CResult;
            HistoricaR.MODIFY(TRUE);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', true, true)]
    local procedure "FSN Utility_OnInvokeGlobalChannelEvent"
(
    var XMLRequest: Text;
    var XMLResponse: Text;
    var RequestID: Text[50];
    var POSMenuLine: Record "LSC POS Menu Line";
    var Processed: Boolean;
    var MsgResult: Text
)
    var
        OperadoresTelefonia_l: Record "FSN Operadoras Telefonicas";
        rRecargasElectronicas: Record "FSN Recargas Electronicas";
    begin
        if RequestID = 'GETITEMRECARGA' then begin
            CLEAR(OperadoresTelefonia_l);
            OperadoresTelefonia_l.RESET;
            OperadoresTelefonia_l.SETRANGE(OperadoresTelefonia_l."No. Producto", POSMenuLine.Parameter);
            if OperadoresTelefonia_l.FIND('-') then begin
                Processed := true;
            end ELSE BEGIN
                Processed := false;
            END;
        end;

        if RequestID = 'GETRECEIPTRECARGA' then begin
            rRecargasElectronicas.RESET;
            rRecargasElectronicas.SETRANGE("Receipt No.", POSMenuLine."Current-RECEIPT");
            IF rRecargasElectronicas.FINDFIRST THEN BEGIN
                POSMenuLine."Primary Key" := rRecargasElectronicas."Transaccion Operador";
                POSMenuLine."POS Action Message" := rRecargasElectronicas."Numero Telefono";
                POSMenuLine."Image URI" := rRecargasElectronicas."Tipo Paquete";
            END
        end;
    end;
}