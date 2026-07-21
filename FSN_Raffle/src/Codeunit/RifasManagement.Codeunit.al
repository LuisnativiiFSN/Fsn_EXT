codeunit 50039 "FSN RifasManagement"
{
    trigger OnRun()
    begin
    end;

    var
        POSGUI: Codeunit "LSC POS GUI";
        xValTran: Decimal;
        GlobalCustomer: Code[20];
        LineLen: Integer;
        InvLineLen: Integer;
        Value: array[10] of Text[250];
        PrintBuffer: Record "LSC POS Print Buffer" temporary;
        PrintBufferIndex: Integer;
        PageNo: Integer;
        LinesPrinted: Integer;
        IsInvoice: Boolean;
        PosSetup: Record "LSC POS Hardware Profile";
        PrintUL: Codeunit "LSC POS Print Utility";
        POSTransaction: Codeunit "LSC POS Transaction";
        gRifaNo: Code[30];
        gPremiado: Boolean;
        gRealBalance: Decimal;
        RifasMgt: Codeunit "FSN RifasManagement";
        MultiplePrintNoGenerado: Integer;
        RifaGeneradorCodigo: code[30];

    procedure CheckApplyPosTmp(var pPosLineTmp: Record "LSC POS Trans. Line" temporary; var pHeaderTmp: Record "LSC POS Transaction" temporary; var pMsg: Text; var Apply: Boolean; pRifaTable: Record "FSN Rifas"): Boolean
    var
        pRifaDet: Record "FSN RifasDetalle";
        pTransLineGruposTmp: Record "LSC POS Trans. Line" temporary;
        SpecialLinksProd: Record "LSC Item/Special Group Link";
        SpecialLinkExclude: Record "LSC Item/Special Group Link";
        Inserted_: Boolean;
        GroupsSalesAmt: Decimal;
        CountGroup: Integer;
        lText001: Label 'TIPO DE CLIENTE %1 NO PARTICIPA EN RIFA %2';
        lText002: Label 'CLIENTE NO POSEE NINGUNA MARCA';
        lText003: Label 'REGISTRA A TU CLIENTE PARA QUE  PARTICIPE EN EL SORTEO DE PAVOS';
        lText004: Label 'A TU CLIENTE SOLO LE FALTA %1 MARCA(s) PARA PARTICIPAR EN EL SORTEO DE %2';
        lText005: Label 'A TU CLIENTE SOLO LE FALTAN $%1 (EN COMPRA) PARA PODER PARTICIPAR EN EL SORTEO DE %2';
        lText006: Label '¡¡ TU CLIENTE PODRÁ PARTICIPAR EN EL SORTEO DE PAVOS, DESÉALE MUCHA SUERTE !!';
        RifasExClient: Record "FSN Rif. Excl. Cust Disc Group";
        Customer: Record Customer;
        TotalSalesAmount: Decimal;
        lText007: Label 'A TU CLIENTE SOLO LE FALTAN $%1 (EN MARCAS) PARA PODER PARTICIPAR EN EL SORTEO DE %2';
    begin
        CLEAR(Apply);
        pTransLineGruposTmp.RESET;
        pTransLineGruposTmp.DELETEALL;
        CLEAR(pTransLineGruposTmp);
        CLEAR(GroupsSalesAmt);
        CLEAR(CountGroup);
        CLEAR(TotalSalesAmount);

        IF pHeaderTmp."Customer No." = '' THEN BEGIN
            pMsg := lText003;
            EXIT(FALSE);
        END;
        IF NOT Customer.GET(pHeaderTmp."Customer No.") THEN BEGIN
            pMsg := lText003;
            EXIT(FALSE);
        END;
        IF Customer."LSC Retail Customer Group" = 'COMODIN' THEN BEGIN
            pMsg := STRSUBSTNO(lText001, Customer."LSC Retail Customer Group", pRifaTable.Descripcion);
            EXIT(FALSE);
        END;
        IF Customer."FSN Customer Type" = Customer."FSN Customer Type"::Company THEN BEGIN
            pMsg := STRSUBSTNO(lText001, FORMAT(Customer."FSN Customer Type"::Company), pRifaTable.Descripcion);
            EXIT(FALSE);
        END;

        IF RifasExClient.GET(pRifaTable.NoRifa, Customer."Customer Disc. Group") THEN BEGIN
            pMsg := STRSUBSTNO(lText001, Customer."Customer Disc. Group", pRifaTable.Descripcion);
            EXIT(FALSE);
        END;

        IF NOT pPosLineTmp.FIND('-') THEN
            Apply := FALSE
        ELSE
            REPEAT
                CLEAR(Inserted_);
                IF NOT SpecialLinkExclude.GET(pPosLineTmp.Number, 'RIFASEXCL') THEN BEGIN

                    pRifaDet.RESET;
                    pRifaDet.SETCURRENTKEY("No Rifa", "Line No");
                    pRifaDet.SETRANGE(pRifaDet."No Rifa", pRifaTable.NoRifa);
                    pRifaDet.SETRANGE(pRifaDet.Tipo, pRifaDet.Tipo::"Grupos Especiales");
                    IF pRifaDet.FIND('-') THEN
                        REPEAT
                            IF SpecialLinksProd.GET(pPosLineTmp.Number, pRifaDet.CodSec) THEN BEGIN
                                Inserted_ := TRUE;
                                IF NOT pTransLineGruposTmp.GET(pRifaDet.CodSec, 0) THEN BEGIN
                                    CountGroup += 1;
                                    pTransLineGruposTmp.INIT;
                                    pTransLineGruposTmp."Line No." := 0;
                                    pTransLineGruposTmp."Receipt No." := SpecialLinksProd."Special Group Code";
                                    pTransLineGruposTmp.Quantity := 0;
                                    pTransLineGruposTmp.Amount := 0;
                                    pTransLineGruposTmp.INSERT;
                                END;
                                pTransLineGruposTmp.Quantity += 1;
                                pTransLineGruposTmp.Amount += pPosLineTmp.Amount;
                                GroupsSalesAmt += pPosLineTmp.Amount;
                                pTransLineGruposTmp.MODIFY;
                                pPosLineTmp."Item Disc. Group" := SpecialLinksProd."Special Group Code";
                                pPosLineTmp.Marked := TRUE;
                                pPosLineTmp.MODIFY;
                            END;
                        UNTIL (pRifaDet.NEXT = 0) OR Inserted_;

                    TotalSalesAmount += pPosLineTmp.Amount;
                END;//Exclude static
            UNTIL pPosLineTmp.NEXT = 0;

        pHeaderTmp.Prepayment := GroupsSalesAmt;
        pHeaderTmp.MODIFY;

        pTransLineGruposTmp.RESET;
        Apply := pRifaTable.CondMinimas <= CountGroup;
        IF NOT Apply THEN BEGIN
            pMsg := STRSUBSTNO(lText004, FORMAT(pRifaTable.CondMinimas - CountGroup), pRifaTable.Descripcion);
            EXIT(FALSE);
        END;

        //Apply := pRifaTable.ValorMinimo <= GroupsSalesAmt;
        Apply := pRifaTable.ValorMinimo <= TotalSalesAmount;
        IF NOT Apply THEN BEGIN
            pMsg := STRSUBSTNO(lText005, FORMAT(ROUND(pRifaTable.ValorMinimo - TotalSalesAmount, 0.01)), pRifaTable.Descripcion);
            EXIT(FALSE);
        END;
        //Apply := 5 <= GroupsSalesAmt;
        /*IF NOT Apply THEN BEGIN
            pMsg := STRSUBSTNO(lText007, FORMAT(ROUND(5 - GroupsSalesAmt, 0.01)), pRifaTable.Descripcion);
            EXIT(FALSE);
        END;*/

        IF Apply THEN
            pMsg := lText006;

        EXIT(Apply);
    end;

    procedure CifrarCodigo(ValueEncrypt: Text[5]; SerieText: Text[5]; lNumberPOS: Integer; lNumberSerie: Integer; NoSeriesCode: Code[10]) NewEncrypt: Text[20]
    var
        lNumberXlNumber: Integer;
        lNumber2: Integer;
        lCharExtra: Char;
        lCharExtra2: Char;
        NewValueEncrypt: Text[20];
        CurrentSerie: Text[10];
        lText001: Label 'El numero de autorizacion de la serie %1 debe tener al menos cuatro caracteres';
        NoSeriesLine: Record "No. Series Line";
        AutorizedNumber: Text[25];
    begin
        lNumberXlNumber := (lNumberPOS MOD 16) + 97;
        lNumber2 := 89 - (lNumberPOS MOD 16);
        lCharExtra := lNumberXlNumber;
        lCharExtra2 := lNumber2;
        EVALUATE(lCharExtra, FORMAT(lCharExtra, 0, '<CHAR>'));
        EVALUATE(lCharExtra2, FORMAT(lCharExtra2, 0, '<CHAR>'));

        NoSeriesLine.SETCURRENTKEY(NoSeriesLine."Series Code", NoSeriesLine."Starting Date", NoSeriesLine."Starting No.");
        NoSeriesLine.SETRANGE(NoSeriesLine."Series Code", NoSeriesCode);
        NoSeriesLine.SETFILTER(NoSeriesLine."Starting Date", '<=%1', TODAY);
        NoSeriesLine.SETRANGE(NoSeriesLine."Starting No.", '1');
        IF NoSeriesLine.FINDSET THEN BEGIN
            NoSeriesLine.SETRANGE(NoSeriesLine.Open, TRUE);
            IF NoSeriesLine.FINDFIRST THEN
                AutorizedNumber := NoSeriesLine."FSN Autorization";
        END
        ELSE BEGIN
            POSGUI.PosMessage(STRSUBSTNO(lText001, NoSeriesCode));
            EXIT('');
        END;

        IF STRLEN(AutorizedNumber) < 4 THEN BEGIN
            POSGUI.PosMessage(STRSUBSTNO(lText001, NoSeriesCode));
            EXIT('')
        END;

        IF ((lNumberSerie MOD 3) = 0) AND ((lNumberSerie MOD 5) = 0) THEN
            NewValueEncrypt := FORMAT(lCharExtra) + FORMAT(lCharExtra) + ValueEncrypt + LOWERCASE(COPYSTR(UPPERCASE(AutorizedNumber), 1, 1)) + SerieText
        ELSE
            IF (lNumberSerie MOD 3) = 0 THEN
                NewValueEncrypt := ValueEncrypt + FORMAT(lCharExtra2) + COPYSTR(UPPERCASE(AutorizedNumber), 2, 1) + SerieText + FORMAT(lCharExtra)
            ELSE
                IF (lNumberSerie MOD 2) = 0 THEN
                    NewValueEncrypt := LOWERCASE(COPYSTR(UPPERCASE(AutorizedNumber), 3, 1)) + ValueEncrypt + '0' + SerieText + FORMAT(lCharExtra)
                ELSE
                    NewValueEncrypt := SerieText + COPYSTR(UPPERCASE(AutorizedNumber), 4, 1) + '0' + ValueEncrypt + FORMAT(lCharExtra2);

        IF ((lNumberSerie MOD 7) = 0) THEN
            NewValueEncrypt := UPPERCASE(NewValueEncrypt);

        IF (STRPOS(NewValueEncrypt, 'O') > 0) OR (STRPOS(NewValueEncrypt, 'o') > 0) THEN BEGIN     //WVILLALTA22MAY18 v2-
            NewValueEncrypt := CONVERTSTR(NewValueEncrypt, 'o', 'k');
            NewValueEncrypt := CONVERTSTR(NewValueEncrypt, 'O', 'K');
        END;                                                                                 //WVILLALTA22MAY18 v2+
        EXIT(NewValueEncrypt);
    end;

    procedure GenerarHexadecimal(Number: Integer) Hexadecimal: Text[5]
    var
        lAnsiValue: Integer;
        lUnicodeValue: Char;
        lNumber: Integer;
        lRemaining1: Integer;
        lRemaining2: Integer;
        lRemaining3: Integer;
        lRemainingExtra: Integer;
        lRemainingExtra2: Integer;
        lChar1: Char;
        lChar2: Char;
        lChar3: Char;
        LCharExtra: Char;
        lCharExtra2: Char;
        Extra1: Boolean;
        Extra2: Boolean;
        lText001: Label '%1%2%3%4%5';
        lText002: Label 'No se puede sobrepasar el limite de serie 1000000.';
    begin
        lNumber := Number;
        IF Number > 1000000 THEN BEGIN
            POSGUI.PosMessage(lText002);
            EXIT('');
        END;
        //Step1
        lRemaining1 := lNumber MOD 16;
        IF lRemaining1 < 10 THEN
            lRemaining1 := 48 + lRemaining1
        ELSE
            lRemaining1 := 55 + lRemaining1;


        //Step2
        lRemaining2 := lNumber DIV 16;
        lRemaining2 := lRemaining2 MOD 16;
        IF lRemaining2 < 10 THEN
            lRemaining2 := 48 + lRemaining2
        ELSE
            lRemaining2 := 55 + lRemaining2;


        Extra1 := FALSE;
        Extra2 := FALSE;
        //STEP3
        lRemaining3 := (lNumber DIV 16) DIV 16;
        IF lRemaining3 >= 16 THEN BEGIN
            lRemainingExtra := lRemaining3 MOD 16;
            IF lRemainingExtra < 10 THEN
                lRemainingExtra := 48 + lRemainingExtra
            ELSE
                lRemainingExtra := 55 + lRemainingExtra;
            lRemaining3 := lRemaining3 DIV 16;
            //Para 1,000,000 de codigos
            IF lRemaining3 >= 16 THEN BEGIN
                lRemainingExtra2 := lRemaining3 MOD 16;
                IF lRemainingExtra2 < 10 THEN
                    lRemainingExtra2 := 48 + lRemainingExtra2
                ELSE
                    lRemainingExtra2 := 55 + lRemainingExtra2;
                lRemaining3 := lRemaining3 DIV 16;

                Extra2 := TRUE;
            END;

            Extra1 := TRUE;
        END;

        IF lRemaining3 < 10 THEN
            lRemaining3 := 48 + lRemaining3
        ELSE
            lRemaining3 := 55 + lRemaining3;


        lChar1 := lRemaining1;
        lChar2 := lRemaining2;
        lChar3 := lRemaining3;
        LCharExtra := lRemainingExtra;
        lCharExtra2 := lRemainingExtra2;
        EVALUATE(lChar1, FORMAT(lChar1, 0, '<CHAR>'));
        EVALUATE(lChar2, FORMAT(lChar2, 0, '<CHAR>'));
        EVALUATE(lChar3, FORMAT(lChar3, 0, '<CHAR>'));
        EVALUATE(LCharExtra, FORMAT(LCharExtra, 0, '<CHAR>'));
        EVALUATE(lCharExtra2, FORMAT(lCharExtra2, 0, '<CHAR>'));
        IF Extra2 THEN
            EXIT(STRSUBSTNO(lText001, lChar3, LCharExtra, lCharExtra2, lChar2, lChar1))
        ELSE
            IF Extra1 THEN
                EXIT(STRSUBSTNO(lText001, '0', lChar3, LCharExtra, lChar2, lChar1))
            ELSE
                EXIT(STRSUBSTNO(lText001, '0', '0', lChar3, lChar2, lChar1));
    end;

    procedure LogParticipacionRifa(pRifaNo: Code[30]; pStoreNo: Code[10]; pReceiptNo: Code[30]; pGanador: Boolean; pNumGenerado: Integer; pProbabilidad: Decimal): Text
    var
        xRifaLog: Record "FSN RifasHistorialF";
        RifasList: record "FSN Rifas";
    begin

        // Actualizar total de premios otorgados en el server
        //xWs := xWs.RifasMgt();
        IF RifasList.GET(pRifaNo) and not (RifasList.OffValidate) THEN
            IF pGanador THEN BEGIN
                //IF NOT xWs.ActualizarDisponibilidad(pRifaNo, pStoreNo) THEN BEGIN
                pRifaNo := updatePremiosOtorgados(pRifaNo, pStoreNo);
                //pRifaNo := 'MISCOMMUNICATION';
                //END;
            END;

        CLEAR(xRifaLog);
        xRifaLog.INIT;
        xRifaLog."Rifa No" := pRifaNo;
        xRifaLog."Store No" := pStoreNo;
        xRifaLog."Receipt No" := pReceiptNo;
        xRifaLog.Fecha := TODAY;
        xRifaLog.Ganador := pGanador;
        xRifaLog.NumGenerado := pNumGenerado;
        xRifaLog.Probabilidad := pProbabilidad;
        IF NOT xRifaLog.INSERT(TRUE) then
            xRifaLog.Modify(TRUE);

        EXIT(pRifaNo);
    end;

    procedure HayRifasActivas(pStoreNo: Code[10]): Code[30]
    var
        xRifas: Record "FSN Rifas";
        xRifasTda: Record "FSN RifasTiendas";
    begin
        // Devuelve TRUE si hay rifas activas para una tienda determinada, esto con la finalidad de hacer el chequeo por etapas.
        CLEAR(xRifasTda);
        xRifasTda.SETRANGE("Store No", pStoreNo);
        IF xRifasTda.FIND('-') THEN
            REPEAT
                // Buscar la rifa para determinar si las fechas aplican
                CLEAR(xRifas);
                xRifas.SETRANGE(NoRifa, xRifasTda."No Rifa");
                xRifas.SETRANGE(xRifas.TipoDisparador, xRifas.TipoDisparador::" ");
                IF xRifas.FIND('-') THEN BEGIN
                    // Verificar fechas de vigencia
                    IF (xRifas.FechaInicio <> 0D) AND (xRifas.FechaFin <> 0D) THEN BEGIN
                        IF (TODAY >= xRifas.FechaInicio) AND (TODAY <= xRifas.FechaFin) THEN
                            EXIT(xRifas.NoRifa);
                        //ELSE           //WVILLALTA18MAY18 -+
                        //EXIT(FALSE);
                    END ELSE BEGIN
                        EXIT(xRifas.NoRifa);
                    END;
                END;
            UNTIL xRifasTda.NEXT <= 0;

        EXIT(''); //WVILLALTA18MAY18 v2.-+
    end;

    procedure VerificarAplicabilidad(pReceiptNo: Code[20]; pStoreNo: Code[10]; pRifaNo: Code[30]): Code[30]
    var
        xTran: Record "LSC POS Trans. Line";
        xRifasTiendas: Record "FSN RifasTiendas";
        xRifa: Record "FSN Rifas";
        xAplica: Boolean;
        xNoRifa: Code[30];
        nAvail: Integer;
        nGranted: Integer;
        xParams: Record "FSN RifasParam";
        nItemsQualify: Integer;
        nAmountQualify: Decimal;
        xItem: Record "Item";
        xRifaDet: Record "FSN RifasDetalle";
        xGrpDet: Record "LSC Item/Special Group Link";
        xFiltro: array[10] of Code[20];
        xIndex: Integer;
        xTranH: Record "LSC POS Transaction";
        xCust: Record Customer;
        xCondMin: Integer;
        xCantMin: Decimal;
        xCondMet: Integer;
        xFailed: Boolean;
        xSalir: Boolean;
        xClienteVIP: Boolean;
        xValMin: Decimal;
        xYa: Boolean;
        xGrpExcl: Record "FSN Rif. Excl. Cust Disc Group";
        AmountGroups: Decimal;
        TransTmp: Record "LSC POS Transaction" temporary;
        TransLineTmp: Record "LSC POS Trans. Line" temporary;
        _MSG: Text;
        _REx: Boolean;
        _Apply: Boolean;
    begin
        xAplica := FALSE;
        xNoRifa := '';
        xValTran := 0;
        //WVILLALTA23ABR18-
        // Inicio de evaluación
        CLEAR(xRifa);
        IF (xRifa.GET(pRifaNo)) THEN BEGIN
            xCondMin := xRifa.CondMinimas;
            xValMin := xRifa.ValorMinimo;
            xAplica := TRUE;
            // Localizar el header de la transaccion
            GlobalCustomer := '';
            CLEAR(xTranH);
            xTranH.SETRANGE("Store No.", pStoreNo);
            xTranH.SETRANGE("Receipt No.", pReceiptNo);
            IF xTranH.FIND('-') THEN BEGIN
                GlobalCustomer := xTranH."Customer No.";
                IF xRifa.VIP THEN BEGIN
                    IF (xTranH."Customer No." <> '') THEN BEGIN
                        IF xCust.GET(xTranH."Customer No.") THEN BEGIN
                            IF (xCust."Customer Disc. Group" = 'VIP') THEN
                                xAplica := TRUE
                            ELSE
                                xAplica := FALSE;
                        END ELSE BEGIN
                            xAplica := FALSE;
                        END;
                    END ELSE BEGIN
                        xAplica := FALSE;
                    END;
                END ELSE BEGIN
                    xAplica := TRUE;
                END;

                IF xAplica THEN BEGIN
                    xTranH.CALCFIELDS("Gross Amount");
                    xValTran := xTranH."Gross Amount";
                    IF (xValMin > 0) AND (xValTran >= xValMin) THEN xAplica := TRUE ELSE xAplica := FALSE;
                    IF (xValMin = 0) THEN xAplica := TRUE;
                END;

                // Verificar Grupo de descuento del cliente
                IF xAplica THEN BEGIN
                    xAplica := VerificarCliente(pRifaNo, xTranH."Customer No."); //WVILLALTA23ABR18 v2-+
                END;
            END ELSE BEGIN
                xAplica := FALSE;
            END;

            IF xAplica THEN BEGIN
                // Verificar fechas de vigencia
                IF (xRifa.FechaInicio <> 0D) AND (xRifa.FechaFin <> 0D) THEN BEGIN
                    IF (TODAY >= xRifa.FechaInicio) AND (TODAY <= xRifa.FechaFin) THEN
                        xAplica := TRUE
                    ELSE
                        xAplica := FALSE;
                END ELSE BEGIN
                    xAplica := TRUE;
                END;

                // Verificar Horarios
                IF xAplica THEN BEGIN
                    IF (xRifa.HoraInicio <> 0T) AND (xRifa.HoraFin <> 0T) THEN BEGIN
                        IF (TIME >= xRifa.HoraInicio) AND (TIME <= xRifa.HoraFin) THEN
                            xAplica := TRUE
                        ELSE
                            xAplica := FALSE;
                    END ELSE BEGIN
                        xAplica := TRUE;
                    END;

                    // Verificar si hay premios disponibles para el dia de hoy
                    nAvail := 0;
                    nGranted := 0;
                    IF xAplica THEN BEGIN
                        nAvail := 1;
                        IF nAvail > 0 THEN BEGIN
                            xAplica := FALSE;
                            xCondMet := 0;
                            xFailed := TRUE;
                            xSalir := FALSE;
                            // Recorrer el detalle de la Rifa
                            CLEAR(AmountGroups);//WVILLALTA 12.20-
                                                //WVILLALTA 12.20+
                            CLEAR(xRifaDet);
                            xRifaDet.SETRANGE("No Rifa", xRifa.NoRifa);
                            IF xRifaDet.FIND('-') THEN
                                REPEAT
                                    nItemsQualify := 0;
                                    nAmountQualify := 0;
                                    // Rifa es aplicable, verificar si la transaccion aplica
                                    CASE xRifa.Tipo OF
                                        xRifa.Tipo::Articulos:
                                            BEGIN
                                                CLEAR(xTran);
                                                xTran.SETRANGE("Receipt No.", pReceiptNo);
                                                xTran.SETRANGE("Store No.", pStoreNo);
                                                xTran.SETRANGE("Entry Type", xTran."Entry Type"::Item);
                                                xTran.SETRANGE(Number, xRifaDet.CodSec);
                                                xTran.SETRANGE(xTran."Entry Status", xTran."Entry Status"::" ");//WVILLALTA20DIC19-+
                                                IF xTran.FIND('-') THEN
                                                    REPEAT
                                                        nItemsQualify += xTran.Quantity;
                                                        nAmountQualify += xTran.Amount;
                                                    UNTIL xTran.NEXT <= 0;
                                            END;
                                        xRifa.Tipo::"Grupos Especiales":
                                            BEGIN
                                                //xYa := FALSE;
                                                CLEAR(xTran);
                                                xTran.SETRANGE("Receipt No.", pReceiptNo);
                                                xTran.SETRANGE("Store No.", pStoreNo);
                                                xTran.SETRANGE("Entry Type", xTran."Entry Type"::Item);
                                                xTran.SETRANGE(xTran."Entry Status", xTran."Entry Status"::" ");//WVILLALTA20DIC19-+
                                                IF xTran.FIND('-') THEN
                                                    REPEAT
                                                        CLEAR(xGrpDet);
                                                        xGrpDet.SETRANGE("Special Group Code", xRifaDet.CodSec);
                                                        xGrpDet.SETRANGE("Item No.", xTran.Number);
                                                        IF xGrpDet.FIND('-') THEN BEGIN
                                                            nItemsQualify := 1;
                                                            nAmountQualify += xTran.Amount;
                                                            xYa := TRUE;
                                                        END;
                                                    UNTIL (xTran.NEXT <= 0);
                                            END;
                                    END;

                                    IF (nItemsQualify >= xRifaDet.CantMin) AND (nAmountQualify >= xRifaDet.ValorMin) THEN
                                        xCondMet += 1;

                                    IF (xCondMin > 0) AND (xCondMet >= xCondMin) THEN BEGIN
                                        xAplica := TRUE;
                                        xFailed := FALSE;
                                        xSalir := TRUE;
                                    END;

                                    IF (nItemsQualify >= xRifaDet.CantMin) AND (nAmountQualify >= xRifaDet.ValorMin) THEN
                                        xAplica := TRUE
                                    ELSE
                                        xAplica := FALSE;

                                    AmountGroups += nAmountQualify;//WVILLALTA 11.20-
                                                                   //WVILLALTA 11.20+
                                UNTIL (xSalir) OR (xRifaDet.NEXT <= 0);

                            IF xFailed = FALSE THEN
                                xAplica := TRUE
                            ELSE
                                xAplica := FALSE;
                        END ELSE BEGIN
                            xAplica := FALSE;
                        END;
                    END;
                END;
            END;
        END;

        IF xAplica THEN BEGIN//WVILLALTA 11.20-
            TransTmp.RESET;
            TransTmp.DELETEALL;
            CLEAR(TransTmp);
            TransLineTmp.RESET;
            TransLineTmp.DELETEALL;
            CLEAR(TransLineTmp);

            TransTmp := xTranH;
            IF TransTmp.INSERT THEN;
            xTran.RESET;
            xTran.SETRANGE(xTran."Receipt No.", xTranH."Receipt No.");
            xTran.SETRANGE(xTran."Entry Type", xTran."Entry Type"::Item);
            xTran.SETRANGE(xTran."Entry Status", 0);
            IF xTran.FIND('-') THEN
                REPEAT
                    TransLineTmp := xTran;
                    TransLineTmp.Amount := xTran.Amount;
                    IF TransLineTmp.INSERT THEN;
                UNTIL xTran.NEXT = 0;

            xAplica := CheckApplyPosTmp(TransLineTmp, TransTmp, _MSG, _Apply, xRifa);
            //xAplica := AmountGroups >= xRifa.ValorMinimo;
            //WVILLALTA 11.20+
        END;

        IF xAplica THEN xNoRifa := pRifaNo ELSE xNoRifa := '';
        //WVILLALTA23ABR18+

        EXIT(xNoRifa);
    end;

    procedure VerificarCliente(RifaNo: Code[30]; Customer: Code[20]) Aplica: Boolean
    var
        CustomerREC: Record Customer;
        GrupoDtoClienteExc: Record "FSN Rif. Excl. Cust Disc Group";
        lText001: Label 'COMODIN';
    begin
        IF Customer <> '' THEN BEGIN
            IF CustomerREC.GET(Customer) THEN BEGIN
                IF ((GrupoDtoClienteExc.GET(RifaNo, CustomerREC."Customer Disc. Group")) OR
                  (CustomerREC."LSC Retail Customer Group" = lText001) OR
                  (CustomerREC."FSN Customer Type" = CustomerREC."FSN Customer Type"::Company)) THEN
                    EXIT(FALSE);
                EXIT(TRUE);
            END;
        END;

        EXIT(FALSE);
    end;

    procedure ObtenerDisponibilidad(pRifaNo: Code[30]; pStoreNo: Code[10]): Integer
    var
        WSXMLStandar: Codeunit "FSN WS XML Integration";
        Request: Text;
        Response: Text;
        RetailSetup: Record "LSC Retail Setup";
        BOUtil: Codeunit "LSC BO Utils";
        SetupXML: Text[50];
        Result: Integer;
        ValHO: Text[20];
        Parameter: Record "FSN Parameter";
        ValHOprosess: Boolean;
        FSNRifaTienda: Record "FSN RifasTiendas";
    begin

        if Parameter.Get('VALHORIFA', 'HO') then begin
            IF Parameter.Activo THEN
                ValHO := Parameter.Valor
            else
                ValHO := 'HO';
        END ELSE
            ValHO := 'HO';

        Result := 1;
        RetailSetup.GET();
        Request := BOUtil.CombineValue(3, pRifaNo, GlobalCustomer, RetailSetup."Distribution Location", '', '');
        WSXMLStandar.SetXMLRequest(Request, 'RIFA_TRANS_CUST');
        IF NOT WSXMLStandar.RUN() THEN begin
            Result := 0;
            EXIT(Result);
        end;

        WSXMLStandar.GetXMLResponse(Response, SetupXML);
        IF NOT (pRifaNo = Response) THEN begin
            Result := 0;
            EXIT(Result);
        end;

        Request := BOUtil.CombineValue(3, pRifaNo, GlobalCustomer, ValHO, '', '');//Head office
        WSXMLStandar.SetXMLRequest(Request, 'RIFA_TRANS_CUST');
        IF NOT WSXMLStandar.RUN() THEN begin
            Result := 0;
            EXIT(Result);
        end;

        WSXMLStandar.GetXMLResponse(Response, SetupXML);
        IF NOT (pRifaNo = Response) THEN begin
            Result := 0;
            EXIT(Result);
        end;

        /*Request := BOUtil.CombineValue(3, pRifaNo, GlobalCustomer, RetailSetup."Distribution Location", '', '');
        WSXMLStandar.SetXMLRequestDisponible(Request, pRifaNo, pStoreNo, 'PREMIOS_DISP');
        IF NOT WSXMLStandar.RUN() THEN begin
            Result := 0;
            EXIT(Result);
        end;

        WSXMLStandar.GetXMLResponse(Response, SetupXML);
        IF NOT (pRifaNo = Response) THEN begin
            Result := 0;
            EXIT(Result);
        end;*/

        Request := BOUtil.CombineValue(3, pRifaNo, GlobalCustomer, ValHO, '', '');//Head office
        WSXMLStandar.SetXMLRequestDisponible(Request, pRifaNo, pStoreNo, 'PREMIOS_DISP');
        IF NOT WSXMLStandar.RUN() THEN begin
            Result := 0;
            EXIT(Result);
        end;

        WSXMLStandar.GetXMLResponse(Response, SetupXML);
        IF NOT (pRifaNo = Response) THEN begin
            Result := 0;
            EXIT(Result);
        end;

        Request := BOUtil.CombineValue(3, pRifaNo, GlobalCustomer, ValHO, '', '');//Head office
        WSXMLStandar.SetXMLRequestDisponible(Request, pRifaNo, pStoreNo, 'PREMIOS_DISP_PARAMETER');
        IF NOT WSXMLStandar.RUN() THEN begin
            Result := 0;
            EXIT(Result);
        end;

        WSXMLStandar.GetXMLResponse(Response, SetupXML);
        IF NOT (pRifaNo = Response) THEN begin
            Result := 0;
            EXIT(Result);
        end;

        IF ServerSideReadAvailability(pRifaNo, pStoreNo) > 0 THEN
            Result := 1
        else
            Result := 0;

        EXIT(Result);
    end;

    procedure updatePremiosOtorgados(pRifaNo: Code[30]; pStoreNo: Code[10]): Text
    var
        WSXMLStandar: Codeunit "FSN WS XML Integration";
        Request: Text;
        Response: Text;
        RetailSetup: Record "LSC Retail Setup";
        BOUtil: Codeunit "LSC BO Utils";
        SetupXML: Text[50];
        Parameter: Record "FSN Parameter";
        ValHO: Text;
    begin
        if Parameter.Get('VALHORIFA', 'HO') then begin
            IF Parameter.Activo THEN
                ValHO := Parameter.Valor
            else
                ValHO := 'HO';
        END ELSE
            ValHO := 'HO';

        ServerSideUpdate(pRifaNo, pStoreNo);

        RetailSetup.GET();
        Request := BOUtil.CombineValue(3, pRifaNo, GlobalCustomer, ValHO, '', '');//Head office
        WSXMLStandar.SetXMLRequestDisponible(Request, pRifaNo, pStoreNo, 'UPDATE_PREMIO');
        IF NOT WSXMLStandar.RUN() THEN begin
            pRifaNo := 'MISCOMMUNICATION';
        end else begin
            WSXMLStandar.GetXMLResponse(Response, SetupXML);
            IF (pRifaNo = Response) THEN begin
                //EXIT(pRifaNo);
            end;
        end;

        Request := BOUtil.CombineValue(3, pRifaNo, GlobalCustomer, ValHO, '', '');//Head office
        WSXMLStandar.SetXMLRequestDisponible(Request, pRifaNo, pStoreNo, 'UPDATE_PREMIO_PARAMETER');
        IF NOT WSXMLStandar.RUN() THEN begin
            pRifaNo := 'MISCOMMUNICATION';
        end else begin
            WSXMLStandar.GetXMLResponse(Response, SetupXML);
            IF (pRifaNo = Response) THEN begin
                EXIT(pRifaNo);
            end;
        end;
    end;

    procedure ObtenerProbabilidad(pRifaNo: Code[30]; pStoreNo: Code[10]): Decimal
    var
        RifaStore: Record "FSN RifasTiendas";
    begin
        RifaStore.reset;
        RifaStore.SetRange("Store No", pStoreNo);
        RifaStore.SetRange("No Rifa", pRifaNo);
        if RifaStore.FindLast() then begin
            EXIT(RifaStore.Probabilidad);
        end else begin
            EXIT(0);
        end;
    end;

    procedure ServerSideReadAvailability(pRifaNo: Code[30]; pStoreNo: Code[10]): Integer
    var
        xRifaTienda: Record "FSN RifasTiendas";
        xParametros: Record "FSN RifasParam";
    begin
        CLEAR(xRifaTienda);
        IF xRifaTienda.GET(pRifaNo, pStoreNo) THEN BEGIN
            IF xRifaTienda.ParametrosDiarios THEN BEGIN
                CLEAR(xParametros);
                xParametros.SETRANGE("No Rifa", pRifaNo);
                xParametros.SETRANGE("Store No", pStoreNo);
                xParametros.SETFILTER(Fecha, '<=%1', TODAY);
                xParametros.SETFILTER(FechaFin, '>=%1', TODAY);
                IF xParametros.FIND('-') THEN
                    EXIT(xParametros.PremiosTotales - xParametros.PremiosOtorgados)
                ELSE
                    EXIT(0);
            END ELSE BEGIN
                EXIT(xRifaTienda.PremiosTotales - xRifaTienda.PremiosOtorgados);
            END;
        END ELSE BEGIN
            EXIT(0);
        END;
    end;

    procedure ServerSideReadProbability(pRifaNo: Code[30]; pStoreNo: Code[10]): Decimal
    var
        xRifaTienda: Record "FSN RifasTiendas";
    begin
        CLEAR(xRifaTienda);
        IF xRifaTienda.GET(pRifaNo, pStoreNo) THEN BEGIN
            EXIT(xRifaTienda.Probabilidad);
        END ELSE BEGIN
            EXIT(0);
        END;
    end;

    procedure ServerSideUpdate(pRifaNo: Code[30]; pStoreNo: Code[10]): Boolean
    var
        xRifaTienda: Record "FSN RifasTiendas";
        xParametros: Record "FSN RifasParam";
    begin
        // La idea es actualizar aca el premio otorgado
        CLEAR(xRifaTienda);
        IF xRifaTienda.GET(pRifaNo, pStoreNo) THEN BEGIN
            IF xRifaTienda.ParametrosDiarios THEN BEGIN
                CLEAR(xParametros);
                xParametros.SETRANGE("No Rifa", pRifaNo);
                xParametros.SETRANGE("Store No", pStoreNo);
                xParametros.SETFILTER(Fecha, '<=%1', TODAY);
                xParametros.SETFILTER(FechaFin, '>=%1', TODAY);
                IF xParametros.FIND('-') THEN BEGIN
                    xParametros.PremiosOtorgados += 1;
                    xParametros.MODIFY(TRUE);
                    xRifaTienda.PremiosOtorgados += 1;
                    xRifaTienda.MODIFY(TRUE);
                    COMMIT;
                END ELSE BEGIN
                    xRifaTienda.PremiosOtorgados += 1;
                    xRifaTienda.MODIFY(TRUE);
                END;
            END ELSE BEGIN
                xRifaTienda.PremiosOtorgados += 1;
                xRifaTienda.MODIFY(TRUE);
            END;
        END;

        COMMIT;
        EXIT(TRUE);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction", 'OnBeforePostTransaction', '', true, true)]
    local procedure "LSC POS Transaction_OnBeforePostTransaction"(var Rec: Record "LSC POS Transaction")
    var
        RifasList: Record "FSN Rifas";
        xDesconectado: Boolean;
        xPremiado: Boolean;
        AvisarEmisionCodigo: Boolean;
        xDisponibles: Integer;
        xNumero: Integer;
        xProbabilidad: Decimal;
        xRifaNo: Code[30];
        RetailCustomerGroup: Code[10];
        RifaDescripcion: Text[50];
        NoGeneradoRifa: Text[30];
        lText000: Label 'No pudo evaluarse participación a Rifas. Servidor fuera de línea';
        lText001: Label 'Favorecido en: ';
        lText002: Label 'Suerte para la proxima, No favorecido en: ';
        lText003: Label 'No se pudo imprimir el codigo de participacion %1';
    begin

        xDesconectado := FALSE;
        xPremiado := FALSE;
        xRifaNo := '';
        RetailCustomerGroup := '';

        Rec.CalcFields("Gross Amount");

        IF Rec."Transaction Type" = Rec."Transaction Type"::Sales THEN BEGIN
            IF NOT (Rec."Sale Is Return Sale") THEN BEGIN
                IF Rec."Entry Status" <> Rec."Entry Status"::Voided THEN BEGIN
                    xRifaNo := RifasMgt.HayRifasActivas(Rec."Store No.");
                    IF xRifaNo <> '' THEN BEGIN
                        xRifaNo := RifasMgt.VerificarAplicabilidad(Rec."Receipt No.", Rec."Store No.", xRifaNo);
                        IF (xRifaNo <> '') AND (Rec."Customer No." <> '') THEN BEGIN

                            // Verificar si hay premios disponibles
                            IF RifasList.GET(xRifaNo) and not (RifasList.OffValidate) THEN
                                xDisponibles := RifasMgt.ObtenerDisponibilidad(xRifaNo, Rec."Store No.")
                            else
                                xDisponibles := 1;
                            IF xDisponibles > 0 THEN BEGIN
                                // Obtener Probabilidad
                                xProbabilidad := RifasMgt.ObtenerProbabilidad(xRifaNo, REC."Store No.");
                                IF xProbabilidad >= 0 THEN BEGIN
                                    // Generar Numero de sorteo
                                    RANDOMIZE();
                                    xNumero := RANDOM(100);
                                    //xNumero := 60;
                                    IF xNumero >= (100 - xProbabilidad) THEN
                                        xPremiado := TRUE;
                                END ELSE BEGIN
                                    // No se pudo leer la probabilidad del server
                                    xRifaNo := 'MISCOMMUNICATION';
                                END;
                            END ELSE BEGIN
                                xPremiado := FALSE;
                            END;
                            IF RifasList.GET(xRifaNo) THEN
                                RifaDescripcion := RifasList.Descripcion
                            ELSE
                                RifaDescripcion := xRifaNo;
                            // Registrar participacion de Rifa en Log
                            xRifaNo := RifasMgt.LogParticipacionRifa(xRifaNo, REC."Store No.", REC."Receipt No.", xPremiado, xNumero, xProbabilidad);
                            IF xRifaNo = 'MISCOMMUNICATION' THEN BEGIN
                                POSGUI.PosMessage(lText000);
                            END ELSE BEGIN
                                IF xPremiado THEN
                                    POSGUI.PosMessage(lText001 + RifaDescripcion)
                                ELSE
                                    POSGUI.PosMessage(lText002 + RifaDescripcion);
                            END;
                        END;
                    END;
                END;
            END;
        END;

        IF NOT (REC."Sale Is Return Sale") AND NOT (REC."Entry Status" = REC."Entry Status"::Voided) THEN
            RifaGeneradorCodigo := GeneradorCodigoActivo(REC."Store No.", Rec."Gross Amount", Rec."Gross Amount");
        IF RifaGeneradorCodigo <> '' THEN
            MultiplePrintNoGenerado := ImprimirPorMultiplo(RifaGeneradorCodigo, Rec."Gross Amount", Rec."Gross Amount", Rec);

        IF (RifaGeneradorCodigo <> '') AND (MultiplePrintNoGenerado <> 0) THEN BEGIN
            AvisarEmisionCodigo := TRUE;
            WHILE MultiplePrintNoGenerado <> 0 DO BEGIN
                NoGeneradoRifa := GenerarCodigoParticipacion(Rec, Rec."Gross Amount", Rec."Gross Amount", RifaGeneradorCodigo, AvisarEmisionCodigo);
                MultiplePrintNoGenerado -= 1;
                AvisarEmisionCodigo := FALSE;
                IF NoGeneradoRifa <> '' THEN
                    IF NOT PrintCodigoRifaGenerado(REC, 2, REC."Trans. Date", REC."Trans Time",
                                              RifaGeneradorCodigo, TRUE, NoGeneradoRifa) THEN BEGIN
                        POSGUI.PosMessage(STRSUBSTNO(lText003, NoGeneradoRifa));
                        MultiplePrintNoGenerado := 0;
                    END;
            END;
        end;
    end;

    //generador de codigo 
    procedure GeneradorCodigoActivo(StoreNo: Code[10]; Balance: Decimal; RealBalance: Decimal) RifaNo: Code[30]
    var
        RifasTiendas: Record "FSN RifasTiendas";
        RifasActivas: Record "FSN Rifas";
    begin
        RifasTiendas.RESET;
        RifasTiendas.SETRANGE(RifasTiendas."Store No", StoreNo);
        IF RifasTiendas.FINDSET THEN
            REPEAT
                RifasActivas.RESET;
                IF RifasActivas.GET(RifasTiendas."No Rifa") THEN
                    IF (RifasActivas.TipoDisparador = RifasActivas.TipoDisparador::"Code Generator")
                     AND (RifasActivas.FechaInicio <= TODAY) AND (RifasActivas.FechaFin >= TODAY) THEN
                        EXIT(RifasActivas.NoRifa);
            UNTIL RifasTiendas.NEXT = 0;
        EXIT('');
    end;

    //evalua cuantos a imprimir
    procedure ImprimirPorMultiplo(RifaCode: Code[30]; Balance: Decimal; RealBalance: Decimal; POSTransRec: Record "LSC POS Transaction") MultiplePrint: Integer
    var
        RifasList: Record "FSN Rifas";
        TransHeader: Record "LSC POS Transaction";
        ReturnValue: Integer;
        ConfirmApplicability: Code[30];
        GrossAmount: Decimal;
    begin
        IF RifasList.GET(RifaCode) THEN BEGIN
            IF RifasList.CondMinimas <> 0 THEN BEGIN
                ConfirmApplicability := VerificarAplicabilidad(POSTransRec."Receipt No.", POSTransRec."Store No.", RifaCode);
                IF ConfirmApplicability <> '' THEN BEGIN
                    IF NOT RifasList.MultiplicarImpresion THEN
                        EXIT(1)
                    ELSE
                        EXIT(xValTran DIV RifasList.ValorMinimo);
                END;
            END
            ELSE BEGIN
                TransHeader.RESET;
                IF (TransHeader.GET(POSTransRec."Receipt No.")) AND (VerificarCliente(RifaCode, POSTransRec."Customer No.")) THEN BEGIN
                    TransHeader.CALCFIELDS(TransHeader."Gross Amount");
                    GrossAmount := TransHeader."Gross Amount";
                    IF GrossAmount >= RifasList.ValorMinimo THEN BEGIN
                        IF NOT RifasList.MultiplicarImpresion THEN
                            EXIT(1)
                        ELSE
                            EXIT(TransHeader."Gross Amount" DIV RifasList.ValorMinimo);
                    END;//GrossAmount
                END;//Receipt
            END;//RifasList.CondMinimas
        END;

        EXIT(0);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransactionFiscalProcess', '', true, true)]
    local procedure "LSC POS Post Utility_OnAfterPostTransactionFiscalProcess"
    (
        var TransactionHeader: Record "LSC Transaction Header";
        var FiscalProcessActive: Boolean;
        var FiscalProcessOk: Boolean;
        var POSTransaction: Record "LSC POS Transaction"
    )
    var
        AvisarEmisionCodigo: Boolean;
        NoGeneradoRifa: Text[30];
        RifasHist: Record "FSN RifasHistorialF";
        lText003: Label 'No se pudo imprimir el codigo de participacion %1';
        FsnRifas: Record "FSN Rifas";
    begin
        RifasHist.Reset;
        RifasHist.SetRange(RifasHist."Receipt No", TransactionHeader."Receipt No.");
        if RifasHist.FindFirst then begin
            IF (RifasHist."Rifa No" <> '') AND (RifasHist."Rifa No" <> 'MISCOMMUNICATION') THEN begin
                IF FsnRifas.Get(RifasHist."Rifa No") THEN begin
                    ExtPrint(POSTransaction, 2, RifasHist."Rifa No", false, '', RifasHist.Ganador);
                    //PrintComprobanteRifa(RifasHist."Rifa No", 2, TransactionHeader."Receipt No.", RifasHist.Ganador)
                end;
            end;

        end;
    end;

    procedure RaffleTemporary(RtransactionH: Record "LSC Transaction Header")
    var
        RParameter: Record "FSN Parameter";
        RCustomer: Record Customer;
        Header: Record "LSC POS Print Setup Header";
        POSPrint: Codeunit "LSC POS Print Utility";
        TransSalesEntry: Record "LSC Trans. Sales Entry";
        gruopAmount: Decimal;
        ItemSpecGrLick: REcord "LSC Item/Special Group Link";
        ReturnDateIn: Date;
        ReturnDateEnd: Date;
        DateIni: DateTime;
        DateEnd: DateTime;
    begin
        gruopAmount := 0;
        ReturnDateIn := 0D;
        ReturnDateEnd := 0D;
        if RCustomer.get(RtransactionH."Customer No.") then begin
            RParameter.Reset();
            RParameter.SetRange(Grupo, 'PRINTRIFA');
            RParameter.SetRange(Codigo, RCustomer."Customer Disc. Group");
            IF RParameter.FindFirst() THEN begin
                if RParameter.Activo then
                    if Header.GET(RParameter.Valor) THEN begin
                        TransSalesEntry.RESET;
                        TransSalesEntry.SETRANGE(TransSalesEntry."Store No.", RtransactionH."Store No.");
                        TransSalesEntry.SETRANGE(TransSalesEntry."POS Terminal No.", RtransactionH."POS Terminal No.");
                        TransSalesEntry.SETRANGE(TransSalesEntry."Receipt No.", RtransactionH."Receipt No.");
                        IF TransSalesEntry.FIND('-') THEN
                            REPEAT
                                ItemSpecGrLick.Reset();
                                ItemSpecGrLick.SetCurrentKey("Item No.", "Special Group Code");
                                ItemSpecGrLick.SetRange("Item No.", TransSalesEntry."Item No.");
                                ItemSpecGrLick.SetRange("Special Group Code", RParameter.Descripcion);
                                if not ItemSpecGrLick.FindFirst() then
                                    gruopAmount += TransSalesEntry."Total Rounded Amt.";
                            UNTIL TransSalesEntry.NEXT = 0;
                        if -gruopAmount >= RParameter."Limit Points" then begin
                            IF EVALUATE(DateIni, RParameter."Value Text 1") THEN
                                ReturnDateIn := DT2DATE(DateIni);

                            IF EVALUATE(DateEnd, RParameter."Value Text 2") THEN
                                ReturnDateEnd := DT2DATE(DateEnd);

                            IF (ReturnDateIn <> 0D) AND (ReturnDateEnd <> 0D) THEN BEGIN
                                IF (TODAY >= ReturnDateIn) AND (TODAY <= ReturnDateEnd) THEN
                                    POSPrint.PrintExtra(RtransactionH, Header, 0, RtransactionH.Payment, 0, '', '', '', 1, 0, '', '', '', RtransactionH."Staff ID", '');
                            end;
                        end;
                    end;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransaction', '', true, true)]
    local procedure "POS Post Utility_OnAfterPostTransaction"(var TransactionHeader_p: Record "LSC Transaction Header")
    var
    begin
        if not TransactionHeader_p."Sale Is Return Sale" then
            RaffleTemporary(TransactionHeader_p);
    end;

    //generador de codigo
    procedure GenerarCodigoParticipacion(POSTransRecord: Record "LSC POS Transaction"; Balance: Decimal; RealBalance: Decimal; RifaCode: Code[30]; Altert: Boolean) ValueEncrypt1: Text[30]
    var
        RifasList: Record "FSN Rifas";
        SeriesManager: Codeunit NoSeriesManagement;
        CurrentSerie: Text[20];
        ValueEncrypt: Text[5];
        lText001: Label 'No se pudo obtener un numero de serie de: %1';
        lText002: Label 'Felicidades esta participando en %1 , Se imprimira un codigo para el sorteo.';
        ValueEncrypt2: Text[20];
        Number: Integer;
        NumberText: Text[5];
        NumberPOS: Integer;
        POSTerminalNo_: Text[20];
        CountWhile: Integer;
        NumberRifaRepeat: Record "FSN RifasHistorialF";
        lText003: Label 'El numero de serie que se quiere asignar ya fue usado para: %1';
        FSNRaffleWorld: Record "FSN Raffle Codes";
    begin
        //JNEHEMIAS120822 -
        FSNRaffleWorld.RESET;
        FSNRaffleWorld.SETRANGE(FSNRaffleWorld."POS Terminal No", POSTransRecord."POS Terminal No.");
        FSNRaffleWorld.SETRANGE(FSNRaffleWorld.NoRifa, RifaCode);
        FSNRaffleWorld.SETRANGE(FSNRaffleWorld.Used, FALSE);
        IF FSNRaffleWorld.FIND('-') THEN BEGIN
            FSNRaffleWorld.Used := TRUE;
            FSNRaffleWorld."Receipt No" := POSTransRecord."Receipt No.";
            FSNRaffleWorld.Date := POSTransRecord."Trans. Date";
            FSNRaffleWorld.Hours := POSTransRecord."Trans Time";
            FSNRaffleWorld.MODIFY;
            EXIT(FSNRaffleWorld.Codigo);
        END;
        //JNEHEMIAS120822 +
        EXIT('');
    end;

    //////////////////////////////////////////////PRINT//////////////////////////////////////////////////

    procedure PrintComprobanteRifa(pRifaNo: Code[30]; Tray: Integer; pTrans: Code[20]; pWinner: Boolean): Boolean
    var
        DSTR1: Text[100];
        xRifa: Record "FSN Rifas";
        xTran: Record "LSC Transaction Header";
        Parameter: Record "FSN Parameter";
    begin

        CLEAR(xRifa);
        IF xRifa.GET(pRifaNo) THEN BEGIN
            IF NOT PrintUL.OpenReceiptPrinter(2, 'TENDER', 'PRINTVIP_TICKET', 0, '') THEN
                EXIT(FALSE);

            IF Tray = 2 THEN BEGIN
                //CLEAR(xTran);
                xTran.reset;
                xTran.SETRANGE(xTran."Receipt No.", pTrans);
                if xTran.FindFirst then begin
                    PrintRifaHeader(xTran, 2, xTran.Date, xTran.Time);

                    DSTR1 := COPYSTR('#C######################################', 1);
                    Value[1] := COPYSTR(xRifa.Descripcion, 1, 25);
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                    Value[1] := COPYSTR(xRifa.Descripcion, 25, 39);
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    PrintSeperatorVIP(2);

                    DSTR1 := COPYSTR('#C######################################', 1);
                    Value[1] := '';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    Value[1] := '';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                    DSTR1 := COPYSTR('#C##################', 1);
                    IF pWinner THEN BEGIN
                        IF xRifa.Linea1Gana <> '' THEN BEGIN
                            Value[1] := COPYSTR(xRifa.Linea1Gana, 1, 20);
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));
                        END;
                        IF xRifa.Linea2Gana <> '' THEN BEGIN
                            Value[1] := COPYSTR(xRifa.Linea2Gana, 1, 20);
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));
                        END;
                        IF xRifa.Linea3Gana <> '' THEN BEGIN
                            Value[1] := COPYSTR(xRifa.Linea3Gana, 1, 20);
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));
                        END;
                    END ELSE BEGIN
                        IF xRifa.Linea1Pierde <> '' THEN BEGIN
                            Value[1] := COPYSTR(xRifa.Linea1Pierde, 1, 20);
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));
                        END;
                        IF xRifa.Linea2Pierde <> '' THEN BEGIN
                            Value[1] := COPYSTR(xRifa.Linea2Pierde, 1, 20);
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));
                        END;
                        IF xRifa.Linea3Pierde <> '' THEN BEGIN
                            Value[1] := COPYSTR(xRifa.Linea3Pierde, 1, 20);
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));
                        END;

                        Parameter.Reset();
                        Parameter.SetRange(Parameter.Grupo, 'PRINTEXTLINE');
                        Parameter.SetRange(Parameter.Codigo, 'TEXT');
                        if Parameter.find('-') then begin
                            repeat
                                IF Parameter.Valor <> '' THEN begin
                                    Value[1] := COPYSTR(Parameter.Valor, 1, 38);
                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));

                                    Value[1] := COPYSTR(Parameter.Descripcion, 1, 38);
                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));
                                end;
                            UNTIL Parameter.Next() = 0;

                        end;
                    END;

                    Value[1] := '';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    Value[1] := '';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    PrintSeperatorVIP(2);
                    Value[1] := '';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                    IF pWinner THEN//WVILLALTA01DIC19
                        IF xRifa.ImprimirCond THEN BEGIN
                            DSTR1 := COPYSTR('#C######################################', 1);
                            IF xRifa.Linea1Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea1Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea2Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea2Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea3Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea3Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea4Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea4Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea5Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea5Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea6Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea6Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea7Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea7Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea8Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea8Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea9Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea9Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            IF xRifa.Linea10Cond <> '' THEN BEGIN
                                Value[1] := COPYSTR(xRifa.Linea10Cond, 1, 38);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                        END;

                END;
            END;
            IF NOT PrintUL.ClosePrinter(2) THEN
                EXIT(FALSE);
        END;
    end;

    procedure PrintRifaHeader(var Transaction: Record "LSC Transaction Header"; Tray: Integer; PrDate: Date; PrTime: Time)
    var
        Staff: Record "LSC Staff";
        DSTR1: Text[100];
        StaffName: Text[30];
        blankStr: Text[30];
        rNoSeries: Record "No. Series";
        rNoSeriesLn: Record "No. Series Line";
        rCust: Record "Customer";
        rCompanyInfo: Record "Company Information";
        rCountry: Record "Country/Region";
        rPosTerminal: Record "LSC POS Terminal";
        rPostCode: Record "Post Code";
        Correlativo: Code[20];
        cNoSeriesMgt: Codeunit "NoSeriesManagement";
        Transaccion: Integer;
        k: Integer;
        rTenderType: Record "LSC Tender Type";
        rTransPaymEntry: Record "LSC Trans. Payment Entry";
        CantPagos: Integer;
        TextNRC: Label 'NRC';
        TextRNC: Label 'NIT';
        TextGIRO: Label 'GIRO';
        TextCorrelativo: Label 'CORRELATIVO:';
        TextCodTienda: Label 'COD. TIENDA:';
        TextCaja: Label 'CAJA:';
        TextAutorizacion: Label 'AUTORIZACION:';
        TextTicket: Label 'TICKET';
        TextFecha: Label 'FECHA:';
        TextHora: Label 'HORA:';
        TextNIT: Label 'NIT:';
        TextDUI: Label 'DUI:';
        TextFirma: Label 'FIRMA:';
        TextUnidad: Label 'CANT.';
        TextCodigo: Label 'ARTICULO';
        TextValor: Label 'PRECIO';
        textTotal: Label 'SUBTOTAL';
        TextDUINIT: Label 'DUI/NIT:';
        TextNombre: Label 'NOMBRE:';
        rTransactionAfectada: Record "LSC Transaction Header";
        rStore: Record "LSC Store";
        xTransInfo: Record "LSC Trans. Infocode Entry";
        vDireccionCompleta: Text[200];
        vDireccionParte1: Text[100];
        vDireccionParte2: Text[100];
        vDireccionCortada: Boolean;
        TextCodCliente: Label 'COD. CLIENTE: ';
        Store: Record "LSC Store";
    begin
        Store.GET(Transaction."Store No.");
        //PrintSubHeader
        IF Tray = 2 THEN
            blankStr := PrintUL.StringPad(' ', LineLen - 38)
        ELSE
            IF Tray = 4 THEN
                blankStr := PrintUL.StringPad(' ', InvLineLen - 38);

        CLEAR(Value);
        IF Tray = 2 THEN BEGIN
            //CONSISA-Imprimir Nombre de la empresa...
            PrintUL.PrintLogo(2);
            rCompanyInfo.GET();
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := rCompanyInfo.Name;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CONSISA-Imprimir Codigo Tipo Contribuyente y  No. Reg. Contribuyente de la empresa...
            rCompanyInfo.GET();
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := rCompanyInfo."FSN NRC Description" + ' ' + TextNRC + ':' + rCompanyInfo."FSN NRC";
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CONSISA-Imprimir Giro de la empresa...
            rCompanyInfo.GET();
            //CSPNT191115
            DSTR1 := COPYSTR('#L################################################', 1);
            Value[1] := TextGIRO + ':' + rCompanyInfo."FSN NRC Description";
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CONSISA-Texto Devolucion
            IF Transaction."Sale Is Return Sale" THEN BEGIN
                DSTR1 := COPYSTR('        #C#########', 1);
                Value[1] := 'DEVOLUCION';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, TRUE, FALSE));

                //Imprimir Linea en blanco...
                DSTR1 := COPYSTR('                     ', 1);
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            //CONSISA-Imprimir Nombre de la tienda.
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store.Name;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CONSISA-Imprimir 1era. direccion de la tienda.
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store.Address;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CONSISA-Imprimir 2da. direccion de la tienda.
            //CSPNT011015 Imprimir dirección solo si existe
            IF Store."Address 2" <> '' THEN BEGIN
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := Store."Address 2";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            //CSPNT011015
            //CONSISA-Imprimir Municipio de la tienda
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store.County;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CSPNT011015 Imprimir ciudad de la tienda
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store.City;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CONSISA-Imprimir telefono de la tienda.
            DSTR1 := COPYSTR('#L## #L#################################', 1);
            Value[1] := 'TEL:';
            Value[2] := Store."Phone No.";
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CONSISA-Imprimir el Correlativo..
            //CSRM19092013
            //Correlativo := Transaction."Transaction No.";
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Trans.:' + ' ' + FORMAT(Transaction."Receipt No.");
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CONSISA-Imprimir el No. de la Caja..
            DSTR1 := COPYSTR('#L#################      #R#############', 1);
            Value[1] := TextCodTienda + Store."No.";
            Value[2] := TextCaja + ' ' + Transaction."POS Terminal No.";
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            rPosTerminal.RESET;
            rPosTerminal.SETRANGE("No.", Transaction."POS Terminal No.");
            rPosTerminal.SETRANGE("Store No.", Transaction."Store No.");
            IF rPosTerminal.FINDFIRST THEN BEGIN
                IF (Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie NCF Ticket") THEN BEGIN
                    //CONSISA-Imprimir No. Ticket.
                    DSTR1 := COPYSTR('#L################################', 1);
                    Value[1] := TextTicket + ' ' + Transaction."FSN NCF";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;

            //CONSISA-Imprimir Hora y Fecha.
            CLEAR(Value);
            DSTR1 := '#L##### #L######### #R###### #R#########';
            //Value[1] := Text048 + ':'; ESL
            Value[1] := TextFecha;
            Value[2] := FORMAT(PrDate, 0, '<Day,2>/<Month,2>/<Year4>');
            Value[3] := FORMAT(TextHora);
            Value[4] := FORMAT(TIME, 0, '<Hours12>:<Minutes,2> <AM/PM>');
            //Value[5] := 'CF';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //CSRM14102013
            //CSPNT261115
            IF Transaction."Customer No." = '' THEN BEGIN
                //IF Transaction."Razon Social" <> '' THEN BEGIN
                IF Transaction."FSN NRC Description" <> '' THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := Transaction."FSN NRC Description";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
                IF Transaction."FSN DUI" <> '' THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := TextDUI + ' ' + Transaction."FSN DUI";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
                IF Transaction."FSN NIT" <> '' THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := TextNIT + ' ' + Transaction."FSN NIT";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;
            //CSRM14102013

            //CONSISA-Imprimir informacion del cliente.
            rCust.RESET;
            IF rCust.GET(Transaction."Customer No.") THEN BEGIN
                //CSPNT200116
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := TextCodCliente + rCust."No.";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := rCust.Name;
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                //CONSISA-Imprimir direccion del cliente
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := rCust.Address;
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                //CONSISA-Imprimir direccion 2 del cliente
                IF rCust."Address 2" <> '' THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := rCust."Address 2";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;

                //CONSISA-Imprimir codigo de ciudad del cliente
                IF rCountry.GET(rCust."Country/Region Code") THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := rCountry.Name;
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;

                //CONSISA-Imprimir codigo de NIT y DUI del cliente
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := TextNIT + ' ' + rCust."VAT Registration No.";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := TextDUI + ' ' + rCust."FSN DUI";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := TextNRC + ' ' + rCust."FSN NRC";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                //CSPNT011015 Imprimir Linea en blanco...
                DSTR1 := COPYSTR('                     ', 1);
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            //CSPNT011015 Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
    end;

    procedure PrintSeperatorVIP(Tray: Integer)
    var
        LineLength: Integer;
        DSTR1: Text[50];
    begin
        //PrintSeperator
        IF Tray = 2 THEN
            LineLength := LineLen
        ELSE
            IF Tray = 4 THEN
                LineLength := InvLineLen;

        DSTR1 := '#C' + PrintUL.StringPad('#', LineLength - 2);
        Value[1] := PrintUL.StringPad('=', LineLength);
        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
    end;

    //////////////////////////////////////////////////////////////////////////////////////////////////


    ///////////print codigo generado //////////

    procedure PrintCodigoRifaGenerado(POSTransRecord: Record "LSC POS Transaction"; Tray: Integer; PrDate: Date; PrTime: Time; RifaCode: Code[30]; Winner: Boolean; ValueEncrypt: Text[30]) Printed: Boolean
    //WVILLALTA18MAY18-+
    var
        RifasList: Record "FSN Rifas";
        Raffleworld: Record "FSN Raffle Codes";
        POSPrintSetUp: Record "LSC POS Print Setup Header";
        POSPrintSetUpLine: Record "LSC POS Print Setup Line";
        POSVariable: Record "LSC POS Print Variable";
        FileMgt: Codeunit "File Management";
        PrintEncrypt: boolean;
        DSTR1: text[100];
        lpathtext: text;
        ltext001: Label 'Recibo: ';
        ltext002: Label 'Tienda: ';
        ltext003: Label 'TPV: ';
    begin
        CLEAR(RifasList);
        IF RifasList.GET(RifaCode) THEN BEGIN
            IF NOT PrintUL.OpenReceiptPrinter(2, 'TENDER', 'PRINTVIP_TICKET', 0, '') THEN
                EXIT(FALSE);
            IF Tray = 2 THEN BEGIN
                CLEAR(Raffleworld);
                Raffleworld.SETCURRENTKEY("Receipt No", Date);
                Raffleworld.SETRANGE(Raffleworld.Date, TODAY);
                Raffleworld.SETRANGE(Raffleworld."Receipt No", POSTransRecord."Receipt No.");
                IF Raffleworld.FIND('-') THEN
                    repeat
                        //PrintRifaHeader(Raffleworld,2,Raffleworld.Date,Raffleworld.Time);
                        DSTR1 := COPYSTR('#C######################################', 1);
                        Value[1] := COPYSTR(lText001 + POSTransRecord."Receipt No.", 1, 40);
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        Value[1] := '';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                        Value[1] := COPYSTR(lText003 + POSTransRecord."POS Terminal No.", 1, 40);
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        Value[1] := '';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                        Value[1] := COPYSTR(lText002 + POSTransRecord."Store No.", 1, 40);
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        Value[1] := '';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        PrintEncrypt := FALSE;
                        IF POSPrintSetup.GET(RifasList."Print Extra") THEN BEGIN
                            PrintSeperatorVIP(2);
                            POSPrintSetupLine.SETCURRENTKEY("Setup ID", "Line No.");
                            POSPrintSetupLine.SETRANGE(POSPrintSetupLine."Setup ID", POSPrintSetup."Setup ID");
                            IF POSPrintSetupLine.FINDSET() THEN
                                REPEAT
                                    IF STRPOS(POSPrintSetupLine.Text, '#RIFACODEG') > 0 THEN BEGIN
                                        DSTR1 := COPYSTR('#C##################', 1);
                                        Value[1] := ValueEncrypt;
                                        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1),
                                              POSPrintSetupLine.Wide, POSPrintSetupLine.High, POSPrintSetupLine.Bold,
                                               POSPrintSetupLine.Italic));
                                        PrintEncrypt := TRUE;
                                    END
                                    ELSE
                                        IF STRPOS(POSPrintSetupLine.Text, '#IMGAPP') > 0 THEN BEGIN
                                            lPathText := '';
                                            IF POSVariable.GET(POSPrintSetupLine.Text) THEN BEGIN
                                                lPathText := RifasList.Imagen;
                                                IF lpathtext <> '' THEN BEGIN
                                                    PrintUL.PrintBitmap(2, lPathText, POSPrintSetupLine.Align);
                                                END;//PATH
                                            END;//VARIABLE
                                        END
                                        ELSE BEGIN
                                            DSTR1 := COPYSTR('#L##################', 1);
                                            IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Left) AND
                                              (POSPrintSetupLine.Wide) THEN
                                                DSTR1 := COPYSTR('#L##################', 1)
                                            ELSE
                                                IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Left) THEN
                                                    DSTR1 := '#L######################################'
                                                ELSE
                                                    IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Center) AND
                                                 (POSPrintSetupLine.Wide) THEN
                                                        DSTR1 := COPYSTR('#C##################', 1)
                                                    ELSE
                                                        IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Center) THEN
                                                            DSTR1 := COPYSTR('#C######################################', 1)
                                                        ELSE
                                                            IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Right) AND
                                                         (POSPrintSetupLine.Wide) THEN
                                                                DSTR1 := COPYSTR('#R##################', 1)
                                                            ELSE
                                                                IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Right) THEN
                                                                    DSTR1 := '#R######################################';

                                            Value[1] := POSPrintSetupLine.Text;
                                            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1),
                                                  POSPrintSetupLine.Wide, POSPrintSetupLine.High, POSPrintSetupLine.Bold,
                                                    POSPrintSetupLine.Italic));
                                        END;//IMG
                                UNTIL POSPrintSetupLine.NEXT = 0;
                            PrintSeperatorVIP(2);
                            IF NOT PrintEncrypt THEN BEGIN
                                Value[1] := COPYSTR(ValueEncrypt, 1, 20);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));


                            END;
                        END;//Print EXTRA
                    until Raffleworld.Next = 0;//Transaction
            END;//GET RifaCode
        END;

        IF NOT PrintUL.ClosePrinter(2) THEN
            EXIT(FALSE)
        ELSE
            EXIT(TRUE);
    end;

    procedure ExtPrint(POSTransRecord: Record "LSC POS Transaction"; Tray: Integer; RifaCode: Code[30]; Winner: Boolean; ValueEncrypt: Text[30]; PrintVal: Boolean) Printed: Boolean
    //WVILLALTA18MAY18-+
    var
        RifasList: Record "FSN Rifas";
        Raffleworld: Record "FSN Raffle Codes";
        POSPrintSetUp: Record "LSC POS Print Setup Header";
        POSPrintSetUpLine: Record "LSC POS Print Setup Line";
        POSVariable: Record "LSC POS Print Variable";
        FileMgt: Codeunit "File Management";
        PrintEncrypt: boolean;
        DSTR1: text[100];
        lpathtext: text;
        ltext001: Label 'Recibo: ';
        ltext002: Label 'Tienda: ';
        ltext003: Label 'TPV: ';
        ltext004: Label 'Fecha: ';
        CodeExtPrint: Code[10];
    begin
        CLEAR(RifasList);
        IF RifasList.GET(RifaCode) THEN BEGIN
            IF NOT PrintUL.OpenReceiptPrinter(2, 'TENDER', 'PRINTVIP_TICKET', 0, '') THEN
                EXIT(FALSE);
            IF Tray = 2 THEN BEGIN
                //PrintRifaHeader(Raffleworld,2,Raffleworld.Date,Raffleworld.Time);
                DSTR1 := COPYSTR('#C######################################', 1);
                Value[1] := COPYSTR(lText001 + POSTransRecord."Receipt No.", 1, 40);
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                Value[1] := COPYSTR(lText003 + POSTransRecord."POS Terminal No.", 1, 40);
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                Value[1] := COPYSTR(lText002 + POSTransRecord."Store No.", 1, 40);
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                Value[1] := COPYSTR(ltext004 + format(POSTransRecord."Trans. Date"), 1, 40);
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                PrintEncrypt := FALSE;
                if PrintVal then
                    CodeExtPrint := RifasList."Print Extra"
                else
                    CodeExtPrint := RifasList."Print Extra Perdedor";
                IF POSPrintSetup.GET(CodeExtPrint) THEN BEGIN
                    PrintSeperatorVIP(2);
                    POSPrintSetupLine.SETCURRENTKEY("Setup ID", "Line No.");
                    POSPrintSetupLine.SETRANGE(POSPrintSetupLine."Setup ID", POSPrintSetup."Setup ID");
                    IF POSPrintSetupLine.FINDSET() THEN
                        REPEAT
                            IF STRPOS(POSPrintSetupLine.Text, '#RIFACODEG') > 0 THEN BEGIN
                                DSTR1 := COPYSTR('#C##################', 1);
                                Value[1] := ValueEncrypt;
                                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1),
                                      POSPrintSetupLine.Wide, POSPrintSetupLine.High, POSPrintSetupLine.Bold,
                                       POSPrintSetupLine.Italic));
                                PrintEncrypt := TRUE;
                            END
                            ELSE
                                IF STRPOS(POSPrintSetupLine.Text, '#IMGAPP') > 0 THEN BEGIN
                                    lPathText := '';
                                    IF POSVariable.GET(POSPrintSetupLine.Text) THEN BEGIN
                                        lPathText := RifasList.Imagen;
                                        IF lpathtext <> '' THEN BEGIN
                                            PrintUL.PrintBitmap(2, lPathText, POSPrintSetupLine.Align);
                                        END;//PATH
                                    END;//VARIABLE
                                END
                                ELSE BEGIN
                                    DSTR1 := COPYSTR('#L##################', 1);
                                    IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Left) AND
                                      (POSPrintSetupLine.Wide) THEN
                                        DSTR1 := COPYSTR('#L##################', 1)
                                    ELSE
                                        IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Left) THEN
                                            DSTR1 := '#L######################################'
                                        ELSE
                                            IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Center) AND
                                         (POSPrintSetupLine.Wide) THEN
                                                DSTR1 := COPYSTR('#C##################', 1)
                                            ELSE
                                                IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Center) THEN
                                                    DSTR1 := COPYSTR('#C######################################', 1)
                                                ELSE
                                                    IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Right) AND
                                                 (POSPrintSetupLine.Wide) THEN
                                                        DSTR1 := COPYSTR('#R##################', 1)
                                                    ELSE
                                                        IF (POSPrintSetupLine.Align = POSPrintSetupLine.Align::Right) THEN
                                                            DSTR1 := '#R######################################';

                                    Value[1] := POSPrintSetupLine.Text;
                                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1),
                                          POSPrintSetupLine.Wide, POSPrintSetupLine.High, POSPrintSetupLine.Bold,
                                            POSPrintSetupLine.Italic));
                                END;//IMG
                        UNTIL POSPrintSetupLine.NEXT = 0;
                    PrintSeperatorVIP(2);
                    IF NOT PrintEncrypt THEN BEGIN
                        Value[1] := COPYSTR(ValueEncrypt, 1, 20);
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, FALSE, TRUE, FALSE));


                    END;
                END;//Print EXTRA
            END;//GET RifaCode
        END;

        IF NOT PrintUL.ClosePrinter(2) THEN
            EXIT(FALSE)
        ELSE
            EXIT(TRUE);
    end;
}

