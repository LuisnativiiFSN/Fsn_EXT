/// <summary>
/// Codeunit FSN WS Prefacturador (ID 50093).
/// </summary>
codeunit 50093 "FSN WS Prefacturador"
{
    EventSubscriberinstance = StaticAutomatic;
    trigger OnRun()
    begin


        AR := '[{"Item":"A120","Lote":"LOTE1","DueDate":"2025-01-10","Key":"30000"},{"Item":"A120","Lote":"LOTE3","DueDate":"2025-01-10","Key":"60000"},{"Item":"A120","Lote":"LOTE6","DueDate":"2025-01-10","Key":"90000"},' +
        '{"Item":"A120","Lote":"LOTE10","DueDate":"2025-01-10"}]';

        /*posline.Reset();
        posline.SetRange(posline."Entry Type", posline."Entry Type"::Item);
        posline.SetRange(posline."Receipt No.", 'PV#3750F00000950534');
        if posline.Find('-') then
            repeat
                Clear(poslinetemp);
                if ArrJSON(AR, lote, dt, posline.Number, posline."Receipt No.", inr) then begin
                    poslinetemp := posline;
                    posTransLineInsert := poslinetemp;
                    posTransLineInsert."Line No." := inr;
                    posTransLineInsert."Lot No." := lote;
                    posTransLineInsert."Expiration Date" := dt;
                    posTransLineInsert.Insert(true);
                    posline.Delete();
                end;
            until posline.Next() = 0;*/
    end;

    //si lleba configuracion de lote procedure GetItemByKey
    //optine el array procedure ArrJSON

    var

        lote: Code[20];
        dt: Date;
        posline: Record "LSC POS Trans. Line";
        poslinetemp: record "LSC POS Trans. Line" temporary;
        AR: Text;
        inr: Integer;
        Item: Record Item;
        Barcodes: Record "LSC Barcodes";
        POSTransactionTB: Record "LSC POS Transaction";
        POSTransLineTB: Record "LSC POS Trans. Line";
        PosFuncProfile: Record "LSC POS Func. Profile";
        PosSetup: Record "LSC POS Hardware Profile";
        MembershipCard: Record "LSC Membership Card";
        gMemberClub: Record "LSC Member Club";
        gMemberScheme: Record "LSC Member Scheme";
        gCustomer: Record customer;
        gMemberCard: Record "LSC Membership Card";
        ItemsinTransactionTEMP: Record Item temporary;
        CouponHeaderTEMP: Record "LSC Coupon Header" temporary;
        CompressTransLine: Record "LSC POS Trans. Line" temporary;
        PreBillerExt: Codeunit "FSN PreBiller Extend";
        POSTransactionCU: Codeunit "LSC POS Transaction";
        POSSession: Codeunit "LSC POS Session";
        PosFunc: Codeunit "LSC POS Functions";
        cuponManagement: Codeunit "LSC Coupon Management";
        POSOfferExtUtil: Codeunit "LSC POS Offer Ext. Utility";
        BOUtils: Codeunit "LSC BO Utils";
        FSNUtil: Codeunit "FSN Utility";
        POSGUI: Codeunit "LSC POS GUI";
        TextError: Text;
        gIsMarkLines: Boolean;
        gRequestFromID: Code[20];
        TenderCode: Code[10];
        ReceiptNo_g: Code[20];
        _VIP: Label 'VIP';
        gText001: Label 'No. %1 No existe en la Base Local (%2).';
        gText002: Label 'No se puede recuperar un numero de Recibo para la transaccion.';
        gText003: Label 'No se puede crear una transaccion. %1';
        gText004: Label 'Unidad de medida %1 no existe. No se puede facturar.';
        gText005: Label 'Error asociar la tarjeta membresia %1, %2';
        gText006: Label 'La tarjeta membresia ingresada %1 no esta vinculada al cliente %2';
        gText007: Label 'No se puede crear el registro %1 en la tabla %2';
        gText008: Label 'No se pudo actualizar el contacto membresia. %1';
        gText009: Label 'La tarjeta %1 ya existe';
        gText010: Label 'El beneficiario no puede estar vacio';
        gText011: Label 'El Club Membresia %1 no tiene configurado Periodo de expiración';
        gText012: Label 'No se puede modificar la tarjeta membresia %1';
        gText013: Label 'Tarjeta %1, en Club %2 dentro de esquema %3 fue registrada exitosamente!';
        gText014: Label 'Error de datos. No existe el contacto %1, no se puede renovar';
        gText015: Label 'Error. No se pudo actualizar el cliente %1.';
        gText016: Label 'Error. No se pudo crear el cliente %1.';
        gText017: Label 'No se puede insertar el cliente en la transaccion. %1';
        gText018: Label 'Error en producto %1 %2';
        MANAGERPERMISSION: Label 'MANAGER';
        gText019: Label 'El empleado %1 no tiene permisos de Administrador';
        gText020: Label 'Nada que hacer';
        gText021: Label 'Hecho';
        _COMODIN: Label 'COMODIN';
        gText022: Label 'Cliente %1 esta bloqueado, seleccione otro';
        GLOBALPROCESLOT: text;
        GLOBALDESCRIPTIONV: text;

    #region [internal Methods]
    local procedure isEditableCustomer(Customer: Record Customer): Boolean
    var
        attribute: Record "LSC Attribute Value";
    begin
        attribute.SetRange("Attribute Code", 'CLIENTES');
        attribute.SetRange("Link Type", attribute."Link Type"::Customer);
        attribute.SetRange("Link Field 1", Customer."No.");
        attribute.SetRange("Attribute Value", 'NO EDITABLE');
        if attribute.FindSet() then
            exit(false);

        exit(true);
    end;

    local procedure AddCouponGlobalTemp
    (
        _Code: Code[10];
        _Description: Text[30];
        _Description2: Text[30];
        _Text: Text[50];
        _CalculationType: integer;
        _infocode: Code[10]
    )
    begin
        if not CouponHeaderTEMP.Get(_Code) then begin
            CouponHeaderTEMP.Init();
            CouponHeaderTEMP.Code := _Code;
            CouponHeaderTEMP.Description := _Description;
            CouponHeaderTEMP."Description 2" := _Description2;
            CouponHeaderTEMP."Calculation Type" := _CalculationType;
            CouponHeaderTEMP."FSN infocode" := _infocode;
            CouponHeaderTEMP.Insert();
        end;
    end;

    local procedure AddLine
        (
            _Line: integer;
            _ItemNo_: Code[20];
            _UnitOfMeasure: Code[20];
            _Qty: integer;
            _EntryType: integer;
            var Response_Code: Text[10];
            var Response_Text: Text
        ): Boolean;
    var
        POSTransLine_l: Record "LSC POS Trans. Line";
        ItemStatusLink_l: Record "LSC Item Status Link";
        CouponHeader_l: Record "LSC Coupon Header";
        POSTransLine2_l: Record "LSC POS Trans. Line";
        POSTransLine: Record "LSC POS Trans. Line";
        posTransactionCU: Codeunit "LSC POS Transaction";
        OposUtility: Codeunit "LSC POS OPOS Utility";
        codeResponse: Code[10];
        lText002: Label 'Cupon %1 no se pudo agregar a la transaccion. intentelo de nuevo.';
        lText001: Label 'Producto %1 esta bloqueado para venta';
        response, jObject : JsonObject;
        jToken, auxToken : JsonToken;
        jArray: JsonArray;
        KeyV: Integer;
        LotNo: code[50];
        ExpireDate: date;
        Ent: Integer;
        PosTransLineTemp: Record "LSC POS Trans. Line" temporary;
        posTransLineInsert: Record "LSC POS Trans. Line";
        PosLine: Record "LSC POS Trans. Line";
    begin
        clear(LotNo);
        clear(ExpireDate);
        if POSTransactionTB.Get(ReceiptNo_g) then begin
            POSTransLineTB.init();
            POSTransLineTB."Receipt No." := POSTransactionTB."Receipt No.";
            PosLine.Reset();
            PosLine.SetRange("Receipt No.", POSTransactionTB."Receipt No.");
            if PosLine.FindLast() then
                _Line := PosLine."Line No." + 10000
            else
                _Line := _Line;
            POSTransLineTB."Line No." := _Line;
            POSTransLineTB."Parent Line" := _Line;
            POSTransLineTB."Store No." := POSTransactionTB."Store No.";
            POSTransLineTB."POS Terminal No." := POSTransactionTB."POS Terminal No.";
            POSTransLineTB."Sales Staff" := POSTransactionTB."Sales Staff";//28981

            case _EntryType of
                0:
                    begin
                        if BOUtils.IsBlockSaleOnPOS(_ItemNo_, '', '', POSTransactionTB."Store No.", '', TODAY, ItemStatusLink_l) then begin
                            Response_Code := '0052';
                            Response_Text := StrSubstNo(lText001, _ItemNo_);
                            exit(false);
                        end;

                        if gIsMarkLines then
                            POSTransLineTB."FSN Additional Action" := POSTransLineTB."FSN Additional Action"::ConfirmScann
                        else
                            POSTransLineTB."FSN Additional Action" := POSTransLineTB."FSN Additional Action"::nothing;

                        POSTransLineTB.VALIDATE("Entry Type", POSTransLineTB."Entry Type"::Item);

                        if not Item.Get(_ItemNo_) then begin
                            Response_Code := '0040';
                            Response_Text := StrSubstNo(gText001, _ItemNo_, Item.TABLECAPTION);
                            exit(false);
                        end;

                        POSTransLineTB."Unit of Measure" := _UnitOfMeasure;
                        Barcodes.Reset();
                        Barcodes.SetRange(Barcodes."Item No.", _ItemNo_);
                        Barcodes.SetRange(Barcodes."Unit of Measure Code", _UnitOfMeasure);
                        if Barcodes.FindFirst() then
                            POSTransLineTB."Barcode No." := Barcodes."Barcode No.";

                        POSFunc.PosTransDiscLoadData(ReceiptNo_g, true);
                        POSTransLineTB.VALIDATE(Number, _ItemNo_);
                        POSTransLineTB.VALIDATE(Quantity, _Qty);

                        if not POSTransLineTB.Insert(TRUE) then begin
                            Response_Code := '0051';
                            Response_Text := STRSUBSTNO(gText018, _ItemNo_, GetLASTERRorTEXT);
                            exit(false);
                        end;

                        if POSTransLine_l.Get(POSTransLineTB."Receipt No.", POSTransLineTB."Line No.") then begin
                            UpdateDescPriceVariants(POSTransLine_l);//24102025
                            if GLOBALPROCESLOT <> '' then begin
                                Clear(PosTransLineTemp);
                                if ArrJSON(GLOBALPROCESLOT, LotNo, ExpireDate, _ItemNo_, POSTransLine_l."Receipt No.", Ent) then begin
                                    PosTransLineTemp := POSTransLine_l;
                                    posTransLineInsert := PosTransLineTemp;
                                    posTransLineInsert."Line No." := Ent;
                                    posTransLineInsert."Lot No." := LotNo;
                                    posTransLineInsert."Expiration Date" := ExpireDate;
                                    posTransLineInsert.Insert(true);
                                    POSTransLine_l.Delete();

                                    posTransLineInsert.Validate(Quantity, _Qty);
                                    posTransLineInsert.Modify(true);
                                end;
                            end else begin
                                POSTransLine_l.Validate(Quantity, _Qty);
                                POSTransLine_l.Modify(true);
                            end;
                        end;
                    end;
                6:
                    begin
                        POSGUI.SetCurrMenu(0, POSSession.GetSalesMenu());
                        if not CouponHeader_l.Get(_ItemNo_) then begin
                            Response_Code := '0041';
                            Response_Text := StrSubstNo(gText001, _ItemNo_, CouponHeader_l.TABLECAPTION);
                            exit(false);
                        end;
                        POSTransLineTB.Validate("Entry Type", POSTransLineTB."Entry Type"::Coupon);
                        POSTransLineTB.Validate(Quantity, _Qty);
                        POSTransactionCU.ProcessCoupon(TextError, _ItemNo_, POSTransLineTB);
                        if TextError <> '' then begin
                            Response_Code := '0042';
                            Response_Text := TextError;
                            exit(false);
                        end;
                        if not POSTransLine2_l.Get(ReceiptNo_g, _Line) then begin
                            Response_Code := '0043';
                            Response_Text := StrSubstNo(lText002, _ItemNo_);
                            exit(false);
                        end;

                        if not POSTransLine2_l."Valid in Transaction" then
                            POSTransLine2_l.Delete(true);
                    end;
            end;
        end;
    end;

    procedure UpdateDescPriceVariants(var Line: Record "LSC POS Trans. Line")
    var
        myInt: Integer;
        POSinfocodeSubCode: Record "LSC information Subcode";
        TableSpecInfocode: Record "LSC Table Specific Infocode";
        InfoCodeRec: Record "LSC Infocode";
        infocodeManagement: Codeunit "LSC POS infocode Utility";
        ErrorTxt: text;
        LastCanceled: boolean;
        TSError: Boolean;
        EntryLineNo: Integer;
    begin
        TableSpecInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
        TableSpecInfocode.SetRange(TableSpecInfocode."Table ID", Database::Item);
        TableSpecInfocode.SETRANGE(Value, Line.Number);
        TableSpecInfocode.SETRANGE("Infocode Code", Line.Number);//VARIANTES
        if TableSpecInfocode.FindFirst() then begin
            IF InfoCodeRec.Get(TableSpecInfocode."Infocode Code") THEN BEGIN
                IF InfoCodeRec.Prompt = 'VARIANTES' THEN BEGIN
                    POSinfocodeSubCode.RESET();
                    POSinfocodeSubCode.SETRANGE("Code", InfoCodeRec.Code);
                    POSinfocodeSubCode.SetRange(Description, GLOBALDESCRIPTIONV);
                    IF POSinfocodeSubCode.FINDFIRST THEN BEGIN
                        LastCanceled := FALSE;
                        TSError := FALSE;
                        Clear(GLOBALDESCRIPTIONV);
                        Line.Description := POSinfocodeSubCode.Description;
                        Line.Validate(Price, POSinfocodeSubCode."Amount /Percent");
                        Line.CalcPrices();
                        infocodeManagement.IsinputOk(InfoCodeRec, POSinfocodeSubCode."Subcode", ErrorTxt, Line, LastCanceled, FALSE, FALSE, TSError, Line.Quantity, '', '', FALSE, 0, FALSE, EntryLineNo);
                    END;
                END;
            END;
        END;
    end;

    local procedure AddLineinfocode(Codeinfocode: Code[10]; input: Text; var ErrorTxt: Text[50]; Quantity: integer): Boolean
    var
        POSinfocodeEntry: Record "LSC POS Trans. infocode Entry";
        POSinfocodeEntry2: Record "LSC POS Trans. infocode Entry";
        pPosTransLine: Record "LSC POS Trans. Line";
        pPosTransLine2: Record "LSC POS Trans. Line";
        pPosTransLine3: Record "LSC POS Trans. Line";
        pCouponHeader: Record "LSC Coupon Header";
        POSinfocodeSubCode: Record "LSC information Subcode";
        POSinfocode: Record "LSC infocode";
        POSinfocode2: Record "LSC infocode";
        infocodeManagement: Codeunit "LSC POS infocode Utility";
        infoFunction: Text[10];
        Localinfocode: Code[10];
        SubCodeinput: Code[10];
        LineNoinserted: integer;
        ExitLine: Boolean;
        LastCanceled: Boolean;
        CodeIsSet: Boolean;
        Ok_: Boolean;
        TSError: Boolean;
        lText001: Label 'Configuracion de Codigo de informacion "%1" no es válildo';
        lText002: Label 'No se pudo insertar el texto de informacion.';
        lText003: Label 'Debe existir una linea valia en transaccion para el Codigo de informacion "%1".';
        lText004: Label 'El valor del codigo de informacion esta vacio (%1)';
        lText005: Label 'No se encontro el Cupon %1 vinculado al infocodigo %1, esto es un error de programación';
    begin
        if not POSinfocode.Get(Codeinfocode) or (StrLen(Codeinfocode) > 10) or (Codeinfocode = '') or (input = '') then begin
            if input = '' then
                ErrorTxt := StrSubstNo(lText004, Codeinfocode)
            else
                ErrorTxt := StrSubstNo(lText001, Codeinfocode);
            Exit(false);
        end;

        POSinfocodeSubCode.Reset();
        POSinfocodeSubCode.SetCurrentKey(Code, Subcode);
        POSinfocodeSubCode.SetRange(POSinfocodeSubCode.Code, Codeinfocode);

        pCouponHeader.Reset();
        pCouponHeader.SetCurrentKey(Code);
        pCouponHeader.SetRange(pCouponHeader."FSN infocode", Codeinfocode);
        if pCouponHeader.FindSet() then begin
            pPosTransLine3.Reset();
            pPosTransLine3.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
            pPosTransLine3.SetRange(pPosTransLine3."Receipt No.", ReceiptNo_g);
            pPosTransLine3.SetRange(pPosTransLine3."Entry Type", pPosTransLine3."Entry Type"::Coupon);
            pPosTransLine3.SetRange(pPosTransLine3."Entry Status", pPosTransLine3."Entry Status"::" ");
            if not pPosTransLine3.FindFirst() then begin
                ErrorTxt := StrSubstNo(lText005, pCouponHeader."Description 2", Codeinfocode);
                exit(false);
            end;
        end;

        if (POSinfocode.Type <> POSinfocode.Type::"Text input") or POSinfocodeSubCode.FindFirst() then begin
            ErrorTxt := StrSubstNo(lText001, Codeinfocode);
            exit(false);
        end;

        infocodeManagement.SetinfoCode(Codeinfocode);
        LastCanceled := false;
        infoFunction := 'KEY';
        CodeIsSet := false;
        TSError := false;
        SubCodeinput := '';
        ExitLine := false;

        pPosTransLine2.Reset();
        pPosTransLine2.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        pPosTransLine2.SetRange(pPosTransLine2."Receipt No.", ReceiptNo_g);
        pPosTransLine2.SetRange(pPosTransLine2."Entry Type", pPosTransLine2."Entry Type"::Item);
        pPosTransLine2.SetFilter(pPosTransLine2."Entry Status", '<>%1', pPosTransLine2."Entry Status"::Voided);
        if pPosTransLine2.FindLast() then
            repeat
                POSinfocodeEntry2.Reset();
                POSinfocodeEntry2.SetCurrentKey("Receipt No.", infocode, "Transaction Type", "Line No.");
                POSinfocodeEntry2.SetRange(POSinfocodeEntry2."Receipt No.", pPosTransLine2."Receipt No.");
                POSinfocodeEntry2.SetRange(POSinfocodeEntry2.infocode, Codeinfocode);
                POSinfocodeEntry2.SetRange(POSinfocodeEntry2."Line No.", pPosTransLine2."Line No.");
                if not POSinfocodeEntry2.FindFirst() then begin
                    ExitLine := true;
                    pPosTransLine := pPosTransLine2;
                end;
            until (pPosTransLine2.NEXT(-1) = 0) or ExitLine;

        if not ExitLine then begin
            ErrorTxt := StrSubstNo(lText003, Codeinfocode);
            exit(false);
        end;

        if not infocodeManagement.NextinfoCode(POSinfocode2, LastCanceled, SubCodeinput, CodeIsSet) then
            exit(false);

        if infocodeManagement.IsinfoCodeValid(POSinfocode2, pPosTransLine, 0) then
            Ok_ := infocodeManagement.IsinputOk(POSinfocode2, input, ErrorTxt, pPosTransLine, LastCanceled, FALSE, FALSE, TSError, Quantity, '', '', FALSE, 0, FALSE, LineNoinserted);

        if not Ok_ then
            exit(false);

        POSinfocodeEntry.Reset();
        POSinfocodeEntry.SetCurrentKey("Receipt No.", infocode, "Transaction Type", "Line No.");
        POSinfocodeEntry.SetRange(POSinfocodeEntry."Receipt No.", pPosTransLine."Receipt No.");
        POSinfocodeEntry.SetRange(POSinfocodeEntry.infocode, Codeinfocode);
        //POSinfocodeEntry.SetRange(POSinfocodeEntry."Line No.", LineNoinserted);
        if not POSinfocodeEntry.FindLast() then begin
            ErrorTxt := lText002;
            exit(false);
        end;

        POSinfocodeEntry.ModifyAll(Status, POSinfocodeEntry.Status::Processed);

        exit(true);
    end;

    local procedure ApplyCouponByCouponLine(CouponCode: Code[10]; Store: Code[10]; pClub: Code[10]; pScheme: Code[10]; pCustDiscGroup: Code[10])
    var
        CouponHeader: Record "LSC Coupon Header";
        StorePriceGroup: Record "LSC Store Price Group";
        RetailUtil: Codeunit "LSC Retail Price Utils";
    begin
        if not CouponHeaderTEMP.Get(CouponCode) then
            if CouponHeader.Get(CouponCode) then
                if RetailUtil.DiscValPerValid(CouponHeader."Validation Period ID", TODAY, TIME) and not CouponHeader."FSN Block Suggest" and (CouponHeader.Status = CouponHeader.Status::Enabled) then
                    if (CouponHeader."Member Value" = '') or
                    ((CouponHeader."Member Type" = CouponHeader."Member Type"::Club) and (CouponHeader."Member Value" = pClub)) or
                    ((CouponHeader."Member Type" = CouponHeader."Member Type"::Scheme) and (CouponHeader."Member Value" = pScheme)) then
                        if StorePriceGroup.Get(Store, CouponHeader."Price Group") then
                            AddCouponGlobalTemp(CouponHeader.Code, CouponHeader.Description, CouponHeader."Description 2", CouponHeader."Description", CouponHeader."Calculation Type", CouponHeader."FSN infocode"); //olopez
    end;

    local procedure ApplyCouponByPerDiscLine(OfferNo_: Code[20]; Store: Code[10]; pClub: Code[10]; pScheme: Code[10]; pCustDiscGroup: Code[10])
    var
        StorePriceGroup: Record "LSC Store Price Group";
        CouponHeader_l: Record "LSC Coupon Header";
        PeriodicDiscountHeader: Record "LSC Periodic Discount";
        RetailUtil: Codeunit "LSC Retail Price Utils";
    begin
        if PeriodicDiscountHeader.Get(OfferNo_) then
            if (PeriodicDiscountHeader."Coupon Code" <> '') and not CouponHeaderTEMP.Get(PeriodicDiscountHeader."Coupon Code") then
                if RetailUtil.DiscValPerValid(PeriodicDiscountHeader."Validation Period ID", TODAY, TIME) and
                (PeriodicDiscountHeader.Status = PeriodicDiscountHeader.Status::Enabled) then
                    if CouponHeader_l.Get(PeriodicDiscountHeader."Coupon Code") and
                    StorePriceGroup.Get(Store, PeriodicDiscountHeader."Price Group") then
                        if RetailUtil.DiscValPerValid(CouponHeader_l."Validation Period ID", TODAY, TIME) and
                        (CouponHeader_l.Status = CouponHeader_l.Status::Enabled) and
                        StorePriceGroup.Get(Store, CouponHeader_l."Price Group") and
                        not CouponHeader_l."FSN Block Suggest" then
                            if ((CouponHeader_l."Member Value" = '') or
                            ((CouponHeader_l."Member Type" = CouponHeader_l."Member Type"::Club) and (CouponHeader_l."Member Value" = pClub)) or
                            ((CouponHeader_l."Member Type" = CouponHeader_l."Member Type"::Scheme) and (CouponHeader_l."Member Value" = pScheme))) and
                            ((PeriodicDiscountHeader."Customer Disc. Group" = '') or (PeriodicDiscountHeader."Customer Disc. Group" = pCustDiscGroup)) and
                            ((PeriodicDiscountHeader."Member Value" = '') or
                            ((PeriodicDiscountHeader."Member Type" = PeriodicDiscountHeader."Member Type"::Club) and (PeriodicDiscountHeader."Member Value" = pClub)) or
                            ((PeriodicDiscountHeader."Member Type" = PeriodicDiscountHeader."Member Type"::Scheme) and (PeriodicDiscountHeader."Member Value" = pScheme))) then
                                AddCouponGlobalTemp(CouponHeader_l.Code, CouponHeader_l.Description, CouponHeader_l."Description 2", CouponHeader_l."Description", CouponHeader_l."Calculation Type", CouponHeader_l."FSN infocode"); //olopez
    end;

    local procedure ApplyGetMemberType(pMembershipCard: Text[100]; var pClubCode: Code[10]; var pSchemeCode: Code[10]; var pCustDiscGroup: Code[10])
    var
        lMemberShipCard: Record "LSC Membership Card";
        MemberCardMgt: Codeunit "LSC Member Card Management";
        ErrorText: Text;
    begin
        if lMemberShipCard.Get(pMembershipCard) then begin
            if MemberCardMgt.ValidateCard(lMemberShipCard, ErrorText) then begin
                pClubCode := lMemberShipCard."Club Code";
                pSchemeCode := lMemberShipCard."Scheme Code";
                pCustDiscGroup := PreBillerExt.GetValidCustDiscGroup(pMembershipCard);
            end;
        end;
    end;

    local procedure CreateHeader
    (
        Store_No: Code[10];
        Terminal_No: Code[10];
        StaffID: Code[20];
        Sales_Staff: Code[20];
        ManagerKey_: Code[20];
        Customer_No: Code[20];
        Card_No: Code[20];
        CustDiscGroupTemp_: Code[20];
        MemberPoints: Decimal;
        RequestFromID: Code[20];
        OnlyCalculate_l: Boolean;
        var Response_Code: Text[10];
        var Response_Text: Text
    ): Boolean;
    var
        TerminalREC: Record "LSC POS Terminal";
        StoreREC: Record "LSC Store";
        SalesStaffREC: Record "LSC Staff";
        MemberCardREC: Record "LSC Membership Card";
        CustomerREC: Record Customer;
        MemberAccREC: Record "LSC Member Account";
        SalesPerson: Record "Salesperson/Purchaser";
        MemberCardMnt: Codeunit "LSC Member Card Management";
        ReceiptNo_l: Code[20];
        NewCustDiscGroup: Code[20];
        NEWTRANSACTION: Label 'NEW';
    begin
        //Verifica el Terminal
        if not TerminalREC.Get(Terminal_No) then begin
            Response_Code := '0010';
            Response_Text := StrSubstNo(gText001, Terminal_No, TerminalREC.TABLECAPTION);
            exit(false);
        end;
        //verifica la Tienda
        if not StoreREC.Get(Store_No) then begin
            Response_Code := '0011';
            Response_Text := StrSubstNo(gText001, Store_No, StoreREC.TABLECAPTION);
            exit(false);
        end;

        //ECOMMERCE-+
        if not OnlyCalculate_l and (gRequestFromID in ['DELIVERY', 'POS']) then begin
            if ManagerKey_ <> '' then begin
                if not SalesStaffREC.Get(ManagerKey_) then begin
                    Response_Code := '0018';
                    Response_Text := StrSubstNo(gText001, Sales_Staff, SalesStaffREC.TABLECAPTION);
                    exit(false);
                end;
                if SalesStaffREC."Permission Group" <> MANAGERPERMISSION then begin
                    Response_Code := '0019';
                    Response_Text := StrSubstNo(gText019, Sales_Staff);
                    exit(false);
                end;
            end;

            if not SalesStaffREC.Get(Sales_Staff) then begin
                Response_Code := '0012';
                Response_Text := STRSUBSTNO(gText001, Sales_Staff, SalesStaffREC.TABLECAPTION);
                exit(false);
            end;

            if SalesStaffREC."Employment Type" = SalesStaffREC."Employment Type"::Cashier then begin
                Response_Code := '0016';
                Response_Text := StrSubstNo(gText001, Sales_Staff, SalesStaffREC.TABLECAPTION);
                exit(false);
            end;

            if not SalesPerson.Get(SalesStaffREC."Sales Person") then begin
                Response_Code := '0017';
                Response_Text := StrSubstNo(gText001, Sales_Staff, SalesStaffREC.TABLECAPTION);
                exit(false);
            end;
        end;

        if Customer_No <> '' then begin
            if not CustomerREC.Get(Customer_No) then begin
                Response_Code := '0013';
                Response_Text := StrSubstNo(gText001, Customer_No, CustomerREC.TABLECAPTION);
                exit(false);
            end;

            if CustomerREC.Blocked <> CustomerREC.Blocked::" " then begin
                Response_Code := '0021';
                Response_Text := StrSubstNo(gText022, Customer_No, CustomerREC.Name);
                exit(false);
            end;
        end;

        if Card_No <> '' then begin
            if (CustDiscGroupTemp_ = '') then begin
                if not MemberCardREC.Get(Card_No) then begin
                    Response_Code := '0014';
                    Response_Text := StrSubstNo(gText001, Card_No, MemberCardREC.TABLECAPTION);
                    exit(false);
                end;
                if MemberAccREC.Get(MemberCardREC."Account No.") then
                    if MemberAccREC."Linked To Customer No." <> Customer_No then begin
                        Response_Code := '0015';
                        Response_Text := StrSubstNo(gText006, Card_No, Customer_No);
                        exit(false);
                    end;
            end else
                if OnlyCalculate_l then
                    if CustDiscGroupTemp_ <> '' then
                        Card_No := '';
        end;

        if ReceiptNo_g = '' then begin
            POSSession.init();
            POSSession.SetStore(Store_No);
            POSSession.SetTerminal(Terminal_No);
            POSSession.SetStaff(Sales_Staff);
            PosFunc.initPosFunctions();
            //fragmento de la antigua condicion
            ReceiptNo_l := NEWTRANSACTION;
            ReceiptNo_l := insertTransaction();
        end else
            ReceiptNo_l := ReceiptNo_g;

        if (ReceiptNo_l = NEWTRANSACTION) or (ReceiptNo_l = '') then begin
            Response_Code := '0020';
            Response_Text := gText002;
            exit(false);
        end else
            ReceiptNo_g := ReceiptNo_l;

        NewCustDiscGroup := '';

        if Card_No <> '' then NewCustDiscGroup := PreBillerExt.GetValidCustDiscGroup(Card_No);

        if not (NewCustDiscGroup <> '') then NewCustDiscGroup := CustomerREC."Customer Disc. Group";

        if not initializeHeader
        (
            ReceiptNo_l,
            CustomerREC."No.",
            NewCustDiscGroup,
            CustomerREC."Customer Price Group",
            StoreREC."Store VAT Bus. Post. Gr.",
            Card_No,
            CustDiscGroupTemp_,
            MemberPoints,
            OnlyCalculate_l,
            ManagerKey_
        ) then begin
            Response_Code := '0030';
            Response_Text := StrSubstNo(gText003, POSTransactionTB.TABLECAPTION);
            exit(false);
        end;

        Clear(CustomerREC);

        exit(true);
    end;

    local procedure GetMemberinfoExt(VAR MemberCardNo: Code[20]);
    VAR
        MemberAccount_l: Record "LSC Member Account";
        MemberCard_l: Record "LSC Membership Card";
        DUI: Code[20];
        MemberCard: Text[100];
        LastMemberCard: Text[100];
        LastValidDate: Text[20];
        Response_Code: Text[10];
        Response_Text: Text;
        NewMemberCard: Text[100];
        MemberText: Text[100];
        Points: Decimal;
        CalculatePoints: Boolean;
    begin
        if MemberCardNo = '' then
            exit;
        if not MemberCard_l.Get(MemberCardNo) then
            Clear(MemberCardNo)
        else
            if not MemberAccount_l.Get(MemberCard_l."Account No.") then
                Clear(MemberCardNo)
            else begin
                MemberText := MemberCardNo;
                GetMemberinfo(MemberAccount_l."No.", MemberText, NewMemberCard, LastValidDate, FALSE, Points, Response_Code, Response_Text);
            end;
        if Response_Code = '0000' then
            MemberCardNo := NewMemberCard
        else
            Clear(MemberCardNo);
    end;

    local procedure GetNombreCliente(var gRecRef: RecordRef): Text
    var
        POSTrans: record "LSC POS Transaction";
        rCliente: Record "Customer";
    begin
        gRecRef.SETTABLE(POSTrans);

        if rCliente.Get(POSTrans."Customer No.") then
            EXIT(rCliente.Name);
    end;

    /// <summary>
    /// Get Item by Key to be used in the prebiller
    /// </summary>
    /// <param name="Item">Recibe una tabla filtrada de Items</param>
    /// <returns>On Objeto de Json</returns>
    local procedure GetItemByKey(Item: Record Item): JsonObject
    var
        ProdGroup: Record "LSC Retail Product Group";
        ItemStatus: Record "LSC Item Status";
        ItemStatusLink: Record "LSC Item Status Link";
        POsActions: Record "LSC POS Actions";
        Attribute: Record "LSC Attribute Value";
        specialGroup: Record "LSC Item/Special Group Link";
        SpecificInfocode: Record "LSC Table Specific Infocode";
        DiscountLine: Record "LSC Periodic Discount Line";
        jObj: JsonObject;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        FSNUtility: Codeunit "FSN Utility";
        MsgResult: text;
        Processed: boolean;
        jArrayVariants: JsonArray;
        jObjVariant: JsonObject;
        Recetario: Boolean;
    begin
        jObj.Add('No_', Item."No.");
        jObj.Add('Description', Item.Description);
        jObj.Add('Barcode', Item."FSN Barcode No.");
        jObj.Add('Laboratory', Item."LSC Attrib 1 Code");

        //? busca el grupo de producto
        ProdGroup.Reset();
        ProdGroup.SetRange(Code, Item."LSC Retail Product Code");
        if ProdGroup.FindFirst() then
            jObj.Add('Group', ProdGroup.Description)
        else
            jObj.Add('Group', '');

        jObj.Add('Division', Item."LSC Division Code");
        jObj.Add('BasePrice', Item."LSC Unit Price Incl. VAT");

        //? verifica el estado del producto
        jObj.Add('State', 'ACTIVO');
        ItemStatusLink.Reset();
        ItemStatusLink.SetRange("Item No.", Item."No.");
        if ItemStatusLink.FindFirst() then begin
            ItemStatus.Reset();
            ItemStatus.SetRange(Code, ItemStatusLink."Status Code");
            if ItemStatus.FindFirst() then
                jObj.Replace('State', ItemStatus.Description);
        end;

        jObj.Add('Place', Item."FSN Showcase No.");
        jObj.Add('Ingredients', Item."Description 2");
        jObj.Add('Image', '~\Images\<descrip.>.<ext.>');
        jObj.Add('Summary', '<INDICACIONES...EFECTOS...>');

        //? busca la accion del producto
        POsActions.Reset();
        POsActions.SetRange("Data ID", Item."No.");
        POsActions.SetRange(Active, true);
        POsActions.SetRange("Data Trigger", 1);
        POsActions.SetRange("Do Action", 4);
        if POsActions.FindFirst() then
            jObj.Add('Alert', POsActions."Message Text")
        else
            jObj.Add('Alert', '');

        //? busca los atributos del producto

        Attribute.Reset();
        Attribute.SetRange("Attribute Code", 'RECETAS');
        Attribute.SetRange("Link Field 1", Item."No.");
        if (Attribute.FindFirst()) or (StrPos(Item."LSC Attrib 2 Code", 'CONTROL') > 0) then
            jObj.Add('RequiredPrescription', 'RECETAS')
        else
            jObj.Add('RequiredPrescription', '');

        if Item."LSC Retail Product Code" in ['01002002', '01002001'] then
            jObj.Replace('RequiredPrescription', 'OPCIONAL');

        //? verificar grupo especial
        if specialGroup.Get(Item."No.", 'COVID') then
            jObj.Add('SpecialGroup', specialGroup."Special Group Code")
        else
            jObj.Add('SpecialGroup', '');

        //? verificar NRECETA
        SpecificInfocode.Reset();
        SpecificInfocode.SetRange(Value, Item."No.");
        SpecificInfocode.SetRange("Infocode Code", 'NRECETA');
        if SpecificInfocode.FindFirst() then
            jObj.Add('Infocode', SpecificInfocode."Infocode Code")
        else
            jObj.Add('Infocode', '');


        //? verificar descuento
        DiscountLine.Reset();
        DiscountLine.SetRange("No.", Item."No.");
        DiscountLine.SetRange("Offer No.", 'NIVELAR_PRECIO_FSN');
        if DiscountLine.FindFirst() then
            jObj.Add('Offert', DiscountLine."Offer No.")
        else
            jObj.Add('Offert', '');

        jObj.Add('UnitCost', Item."Unit Cost");

        IF Item."Item Tracking Code" <> '' THEN
            jObj.Add('Tracking', true)
        else
            jObj.Add('Tracking', false);

        RequestID := 'ITEMMARGEN';
        Processed := false;
        XMLRequest := Item."No.";
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        jObj.Add('Margen', Processed);

        GetVariant(Item."No.", jArrayVariants, Recetario);//24102025

        IF Recetario then begin
            jObj.Add('Recetario', Recetario);
            jObj.Add('Variants', jArrayVariants);
        end else begin
            jObj.Add('Recetario', Recetario);
            jObj.Add('Variants', jArrayVariants);
        end;

        exit(jObj);
    end;

    procedure GetVariant(ItemCode: Code[20]; var jArrayVariants: JsonArray; var Recetario: Boolean)
    var
        myInt: Integer;
        Infocode: Record "LSC infocode";
        InfocodeSub: Record "LSC information Subcode";
        TableSpecInfocode: Record "LSC Table Specific Infocode";
        jObjVariant: JsonObject;
    begin
        Recetario := false;
        TableSpecInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
        TableSpecInfocode.SetRange(TableSpecInfocode."Table ID", Database::Item);
        TableSpecInfocode.SetRange(TableSpecInfocode.Value, ItemCode);
        TableSpecInfocode.SetRange(TableSpecInfocode."Infocode Code", ItemCode);
        if TableSpecInfocode.FindFirst() then begin
            if Infocode.Get(TableSpecInfocode."Infocode Code") then begin
                IF Infocode.Prompt = 'VARIANTES' THEN BEGIN
                    InfocodeSub.SetCurrentKey(Code, Subcode);
                    InfocodeSub.SetRange(InfocodeSub.Code, Infocode.Code);
                    if InfocodeSub.FindSet() then begin
                        Recetario := true;
                        repeat
                            Clear(jObjVariant);
                            jObjVariant.Add('name', InfocodeSub.Description);
                            jObjVariant.Add('price', InfocodeSub."Amount /Percent");
                            jArrayVariants.Add(jObjVariant);
                        until InfocodeSub.next() = 0;
                    end;
                END;
            end;
        END;
    end;

    local procedure initializeHeader
    (
        ReceiptNo_L: Code[20];
        CustomerNo: Code[20];
        CustomerDiscGroup: Code[10];
        CustomerPriceGroup: Code[10];
        StoreVATBusPostGr: Code[10];
        MemberCard: Code[20];
        CustDiscGroupTemp_l: Code[20];
        MemberPoints_l: Decimal;
        OnliCalculate_: Boolean;
        ManagerKey_l: Code[20]
    ): Boolean;
    var
        Customer_l: Record Customer;
    begin
        if POSTransactionTB.Get(ReceiptNo_g) then begin
            if gRequestFromID in ['DELIVERY', 'POS'] then
                POSTransactionTB.Validate("Sales Staff", POSSession.StaffID)
            else
                POSTransactionTB."Sales Staff" := '';

            POSTransactionTB."Trans. Date" := TODAY;
            POSTransactionTB."Trans Time" := TIME;
            POSTransactionTB."original Date" := TODAY;
            POSTransactionTB."Staff ID" := '';
            POSTransactionTB.Validate("Trans. Currency Code", POSTransactionTB."Trans. Currency Code");

            if not OnliCalculate_ and (gRequestFromID <> 'POS') then begin
                POSTransactionTB."Sales Type" := 'DELIVERY';
                if (CustomerNo <> '') and (gRequestFromID = 'DELIVERY') then
                    if Customer_l.Get(CustomerNo) and (Customer_l."Phone No." <> '') then
                        POSTransactionTB."Sell-to Contact No." := Customer_l."Phone No.";
            end;

            if Customer_l.Get(CustomerNo) and (Customer_l."VAT Bus. Posting Group" <> '') then
                POSTransactionTB.Validate("VAT Bus.Posting Group", Customer_l."VAT Bus. Posting Group");

            if (CustomerNo <> '') then begin
                POSTransactionTB."Customer No." := CustomerNo;
                POSTransactionTB.VALIDATE("Price Group Code", CustomerPriceGroup);

                if not (gRequestFromID in ['DELIVERY', 'POS']) and (CustDiscGroupTemp_l <> '') then
                    POSTransactionTB.VALIDATE("Customer Disc. Group", CustDiscGroupTemp_l)
                else
                    if OnliCalculate_ and (CustDiscGroupTemp_l <> '') then
                        POSTransactionTB.VALIDATE("Customer Disc. Group", CustDiscGroupTemp_l)
                    else
                        POSTransactionTB.VALIDATE("Customer Disc. Group", CustomerDiscGroup);
            end;

            if MemberCard <> '' then begin
                POSTransactionTB."Member Card No." := MemberCard;
                POSTransactionTB."Starting Point Balance" := MemberPoints_l;
            end;

            if gRequestFromID in ['DELIVERY', 'POS'] then
                if ManagerKey_l <> '' then
                    POSTransactionTB."Manager ID" := ManagerKey_l;

            POSTransactionTB."Source Type" := POSTransactionTB."Source Type"::Stationary;
            POSTransactionTB.Modify();
        end;

        exit(true);
    end;

    /// <summary>
    /// AddCustLine.
    /// </summary>
    /// <param name="Line No.">integer.</param>
    /// <param name="Response_Code">VAR Text[10].</param>
    /// <param name="Response_Text">VAR Text.</param>
    /// <returns>Return variable insertCustOk of type Boolean.</returns>
    local procedure JsonToXmlFillTableTransactorNode
    (
        pParameters: Record "LSC POS Menu Line";
        JsonString: Text;
        var GlobalsCSWebServiceTable: Record "FSN WebServiceTable"
    )
    var
        JArray: JsonArray;
        JObject: JsonObject;
        _JObject: JsonObject;
        JToken: JsonToken;
        JValue: JsonToken;
        POSTransinfocode_l: Record "LSC POS Trans. infocode Entry";
        POSTransLine_l: Record "LSC POS Trans. Line";
        pPOSCardReqEntry: Record "FSN POS Card Request Entry";
        RetailSetup_l: Record "LSC Retail Setup";
        POSTransaction: Record "LSC POS Transaction";
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
        Customer_l: Record Customer;
        BinList: Record "FSN Bin Bank";
        DELFUNCTION: Codeunit "LSC Delivery Functions";
        POSTransactionCU: Codeunit "LSC POS Transaction";
        DeliveryContact: Record "LSC Delivery Contact Address";
        ArrayKey: Text;
        Keys: List of [Text];
        jTokenValue: Text[100];
        Phone: Text[50];
        FreeText: Text;
        StaffTxt: Text[100];
        Keylink: Text;
        NewCustomerCode: Code[20];
        _index: integer;
        PagosLineNo: integer;
        StrPosint: integer;
        _ValueDecimal: Decimal;
        ManualExit: Boolean;
        lText001: Label 'Staff: ';
        lText002: Label 'Store Suggest: ';
        lText003: Label 'Pedido generado automatico: PARA LLEVAR. %1';
        lText004: Label 'origin: ';
    begin
        ManualExit := FALSE;
        RetailSetup_l.GET;

        POSTransLine_l.RESET;
        POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", pParameters."Current-RECEIPT");
        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
        IF POSTransLine_l.FIND('-') THEN
            PagosLineNo := POSTransLine_l."Line No."
        ELSE
            PagosLineNo := 1;
        TenderTypeSetup_l.GET(pParameters."Current-SALESORDER");

        //leer el json y llenar la tabla
        Jobject.ReadFrom(JsonString);

        //agregar transline de pago
        if JObject.Get('manual', JToken) then begin
            //asignando a el objeto al axuliar
            _JObject := JToken.AsObject();

            //leyendo el nodo de numero de tarjeta
            _JObject.Get('number', JToken);
            jTokenValue := JToken.AsValue().AsText();

            //si el valor es diferente de vacio
            if jTokenValue <> '' then begin
                //crear linea de numero de tarjeta
                jTokenValue := 'No° Tarjeta: ' + jTokenValue;
                POSTransLine_l.Init();
                POSTransLine_l."Receipt No." := pParameters."Current-RECEIPT";
                POSTransLine_l."Line No." := 25;
                POSTransLine_l."Entry Type" := POSTransLine_l."Entry Type"::FreeText;
                POSTransLine_l."Entry Status" := POSTransLine_l."Entry Status"::" ";
                POSTransLine_l."Text Type" := POSTransLine_l."Text Type"::"Freetext Input";
                POSTransLine_l.Validate(Description, jTokenValue);
                POSTransLine_l.Insert(true);

                //creando la linea de informacion de tarjeta
                _JObject.Get('cvv', JToken);
                jTokenValue := 'cvv: ' + JToken.AsValue().AsText();
                _JObject.Get('lastdate', JToken);
                jTokenValue := jTokenValue + ' Fecha Vencimiento: ' + JToken.AsValue().AsText();
                InitLineFreeText(jTokenValue, pParameters."Current-RECEIPT");
                Clear(jTokenValue);
            end;
        end;

        //CLEAR(pPOSCardReqEntry);
        Phone := '';
        jTokenValue := '';
        StaffTxt := '';
        IF POSTransaction.GET(pParameters."Current-RECEIPT") THEN BEGIN
            POSTransLine_l.RESET;
            POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", pParameters."Current-RECEIPT");
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
            IF POSTransLine_l.FINDFIRST THEN
                IF Phone <> '' THEN BEGIN
                    POSTransaction."Sell-to Contact No." := Phone;
                    POSTransaction.MODIFY;
                END;
            StaffTxt := '';
            IF POSTransaction."Sales Staff" <> '' THEN
                StaffTxt := lText001 + POSTransaction."Sales Staff";
        END;

        ManualExit := TRUE;

        GlobalsCSWebServiceTable.INIT();
        GlobalsCSWebServiceTable.LastSlipNo := pParameters."Current-RECEIPT";
        GlobalsCSWebServiceTable.Store := POSTransaction."Store No.";
        GlobalsCSWebServiceTable.Terminal := POSTransaction."POS Terminal No.";
        GlobalsCSWebServiceTable."Order No." := '';
        GlobalsCSWebServiceTable.Date := TODAY;
        GlobalsCSWebServiceTable.Time := TIME;
        GlobalsCSWebServiceTable."Sell-to Contact No." := POSTransaction."Sell-to Contact No.";
        POSTransaction.CalcFields("Gross Amount");
        GlobalsCSWebServiceTable.Amount := POSTransaction."Gross Amount";
        GlobalsCSWebServiceTable."Customer No." := POSTransaction."Customer No.";
        IF Customer_l.GET(POSTransaction."Customer No.") THEN BEGIN
            GlobalsCSWebServiceTable.Mail := Customer_l."E-Mail";
            StrPosInt := STRPOS(Customer_l.Name, ' ');
            IF StrPosInt > 0 THEN BEGIN
                GlobalsCSWebServiceTable."First Name" := COPYSTR(Customer_l.Name, 1, StrPosInt);
                GlobalsCSWebServiceTable."Last Name" := COPYSTR(Customer_l.Name, StrPosInt, MAXSTRLEN(GlobalsCSWebServiceTable."Last Name"));
            END;
            IF Customer_l."FSN DUI" <> '' THEN BEGIN
                GlobalsCSWebServiceTable."Document Personal" := Customer_l."FSN DUI";
                GlobalsCSWebServiceTable."Document Type" := GlobalsCSWebServiceTable."Document Type"::DUI;
            END ELSE
                IF Customer_l."FSN NRC" <> '' THEN BEGIN
                    GlobalsCSWebServiceTable."Document Personal" := Customer_l."FSN NRC";
                    GlobalsCSWebServiceTable."Document Type" := GlobalsCSWebServiceTable."Document Type"::NRC;
                END;
        END;
        GlobalsCSWebServiceTable.INSERT;
        COMMIT;

        //Delivery order
        IF JObject.Get('DeliveryContactAddress', JToken) THEN BEGIN
            IF GlobalsCSWebServiceTable.GET(pParameters."Current-RECEIPT") THEN BEGIN
                //cambio de token a objeto
                _JObject := JToken.AsObject();
                //obtener el valor del token
                _JObject.Get('DCAPhone', JToken);
                jTokenValue := COPYSTR(JToken.AsValue().AsText(), 1, 20);
                IF jTokenValue <> '' THEN
                    IF jTokenValue <> GlobalsCSWebServiceTable."Sell-to Contact No." THEN BEGIN
                        GlobalsCSWebServiceTable."Sell-to Contact No." := jTokenValue;
                        IF POSTransaction.GET(pParameters."Current-RECEIPT") THEN BEGIN
                            POSTransaction."Sell-to Contact No." := GlobalsCSWebServiceTable."Sell-to Contact No.";
                            POSTransaction.MODIFY;
                        END;
                    END;
                _JObject.Get('DCAtypeaddress', JToken);
                jTokenValue := COPYSTR(JToken.AsValue().AsText(), 1, 20);
                IF GlobalsCSWebServiceTable.Store = 'EC' THEN BEGIN//Static use ecommerce
                    GlobalsCSWebServiceTable."Order Type" := GlobalsCSWebServiceTable."Order Type"::HomeOfficeDelivery;
                    IF jTokenValue = '3' THEN //Takeaway = 3
                        GlobalsCSWebServiceTable."Order Type" := GlobalsCSWebServiceTable."Order Type"::HomeOfficeTakeaway;
                END ELSE BEGIN
                    GlobalsCSWebServiceTable."Order Type" := GlobalsCSWebServiceTable."Order Type"::FromStoreDelivery;
                    IF jTokenValue = '3' THEN //Takeaway = 3
                        GlobalsCSWebServiceTable."Order Type" := GlobalsCSWebServiceTable."Order Type"::FromStoreTakeaway;
                END;
                GlobalsCSWebServiceTable.MODIFY;

                POSTransInfocode_l.INIT;
                POSTransInfocode_l."Receipt No." := GlobalsCSWebServiceTable.LastSlipNo;
                POSTransInfocode_l."Transaction Type" := 0;
                POSTransInfocode_l."Line No." := 888;//Internal FSN
                POSTransInfocode_l.Infocode := 'TEXT';
                POSTransInfocode_l."Entry Line No." := 0;
                POSTransInfocode_l.Information := BOUtils.CombineValue(2, GlobalsCSWebServiceTable."Sell-to Contact No.", jTokenValue, '', '', '');
                POSTransInfocode_l."Store No." := GlobalsCSWebServiceTable.Store;
                POSTransInfocode_l.Date := TODAY;
                POSTransInfocode_l.Time := TIME;
                POSTransInfocode_l."POS Terminal No." := GlobalsCSWebServiceTable.Terminal;
                POSTransInfocode_l."Staff ID" := POSTransaction."Sales Staff";
                IF NOT POSTransInfocode_l.INSERT(TRUE) THEN
                    POSTransInfocode_l.MODIFY(TRUE);

                IF jTokenValue = '2' THEN BEGIN
                    POSTransInfocode_l."Line No." := 889;//Internal FSN
                    _JObject.Get('DCAstreetname', JToken);
                    jTokenValue := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSTransInfocode_l.Information));
                    POSTransInfocode_l.Information := jTokenValue;
                    IF NOT POSTransInfocode_l.INSERT(TRUE) THEN
                        POSTransInfocode_l.MODIFY(TRUE);

                    _JObject.Get('DCAaddress', JToken);
                    jTokenValue := COPYSTR(JToken.AsValue().AsText(), 1, MAXSTRLEN(POSTransInfocode_l.Information));
                    IF jTokenValue <> '' THEN BEGIN
                        POSTransInfocode_l.Infocode := 'DDIRECTION';
                        POSTransInfocode_l."Line No." := 6;
                        POSTransInfocode_l.Information := jTokenValue;
                        IF NOT POSTransInfocode_l.INSERT(TRUE) THEN
                            POSTransInfocode_l.MODIFY(TRUE);
                    END;
                END;
            END;
        END;

        IF JObject.Get('freetext', JToken) THEN BEGIN
            _JObject := JToken.AsObject();
            _JObject.Get('instructions', JToken);
            FreeText := COPYSTR(JToken.AsValue().AsText(), 1, 500);
            IF FreeText <> '' THEN
                InitLineFreeText(FreeText, pParameters."Current-RECEIPT");

            _JObject.Get('storeno', JToken);
            FreeText := COPYSTR(JToken.AsValue().AsText(), 1, 10);
            IF FreeText <> '' THEN BEGIN
                IF GlobalsCSWebServiceTable.GET(pParameters."Current-RECEIPT") THEN BEGIN
                    GlobalsCSWebServiceTable."Store Selected" := FreeText;
                    GlobalsCSWebServiceTable.MODIFY;
                END;

                IF StaffTxt <> '' THEN
                    FreeText := lText002 + FreeText + ' ' + StaffTxt + ' ' + lText004 + ' ' + GlobalsCSWebServiceTable.Store;
                InitLineFreeText(FreeText, pParameters."Current-RECEIPT");
            END;
        END;

        IF ManualExit THEN
            EXIT;

        JObject.SelectToken('transactor', JToken);
        /*IF NOT ISNULL(JToken) THEN BEGIN
            CLEAR(pPOSCardReqEntry);
            pPOSCardReqEntry.INIT();
            pPOSCardReqEntry."Distribution Location" := RetailSetup_l."Distribution Location";
            pPOSCardReqEntry."Store No." := RetailSetup_l."Local Store No.";
            pPOSCardReqEntry."Date Key" := TODAY;
            pPOSCardReqEntry.VALIDATE("Entry No.");
            pPOSCardReqEntry.Date := CURRENTDATETIME;
            pPOSCardReqEntry."Receipt No." := pParameters."Current-RECEIPT";

            POSTransLine_l.RESET;
            POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
            POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", pParameters."Current-RECEIPT");
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
            POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
            IF POSTransLine_l.FIND('-') THEN
                pPOSCardReqEntry."Line No." := POSTransLine_l."Line No."
            ELSE
                pPOSCardReqEntry."Line No." := 1;
            pPOSCardReqEntry."Send Audit No" := POSCardIntegration.GenerateReceiptID(pPOSCardReqEntry."Entry No.");
            pPOSCardReqEntry.Command := COPYSTR(GetValueAsText(JToken, 'mode'), 1, 10);
            pPOSCardReqEntry."Trans Audit No" := pPOSCardReqEntry."Send Audit No";
            pPOSCardReqEntry."Receipt ID" := pPOSCardReqEntry."Send Audit No";
            pPOSCardReqEntry.VALIDATE("Replication Counter");
            pPOSCardReqEntry.Plazo := COPYSTR(GetValueAsText(JToken, 'terms'), 1, 10);
            pPOSCardReqEntry."Retailer ID" := '000000000070075';//COPYSTR(GetValueAsText(JToken,'retailerid'),1,10);
            pPOSCardReqEntry."Terminal ID" := '00241940';//COPYSTR(GetValueAsText(JToken,'terminalid'),1,10);
            pPOSCardReqEntry."Trans Authorization" := COPYSTR(GetValueAsText(JToken, 'authorization'), 1, 10);
            pPOSCardReqEntry."Trans Reference" := COPYSTR(GetValueAsText(JToken, 'reference'), 1, 20);
            pPOSCardReqEntry."Amount Input" := COPYSTR(GetValueAsText(JToken, 'amount'), 1, 30);
            Keylink := BOUtils.CombineValue(5, FORMAT(pPOSCardReqEntry."Entry No."), FORMAT(DATE2DMY(pPOSCardReqEntry."Date Key", 1))
                                  , FORMAT(DATE2DMY(pPOSCardReqEntry."Date Key", 2)), FORMAT(DATE2DMY(pPOSCardReqEntry."Date Key", 3))
                                  , pPOSCardReqEntry."Distribution Location");
            Keylink := COPYSTR(Keylink, 1, 50);


            jTokenValue := pPOSCardReqEntry."Amount Input";
            jTokenValue := COPYSTR(GetValueAsText(JToken, 'mask'), 1, 30);
            IF jTokenValue <> '' THEN
                IF STRLEN(jTokenValue) > 6 THEN BEGIN
                    pPOSCardReqEntry.BIN := pParameters.Parameter;
                    pPOSCardReqEntry."Cast Last Numbers" := COPYSTR(jTokenValue, STRLEN(jTokenValue) - 3, 4);
                    pPOSCardReqEntry."Trans Tipo Mssg" := COPYSTR(jTokenValue, 1, 30);
                END;

            pPOSCardReqEntry."Response Web Ok" := pPOSCardReqEntry."Trans Authorization" <> '';
            IF pPOSCardReqEntry."Response Web Ok" THEN
                pPOSCardReqEntry."Authorization Code" := '00';

            pPOSCardReqEntry.Points := '';
            pPOSCardReqEntry."Entity Name" := 'SERFINSA';//Static
            pPOSCardReqEntry."Type Request" := pPOSCardReqEntry."Type Request"::WebPage;
            pPOSCardReqEntry.User := USERID;
            Phone := COPYSTR(GetValueAsText(JToken, 'phone'), 1, 20);
            COMMIT;

            GlobalsCSWebServiceTable.INIT();
            GlobalsCSWebServiceTable.LastSlipNo := pParameters."Current-RECEIPT";
            jTokenValue := COPYSTR(GetValueAsText(JToken, 'delivery'), 1, 30);//WVILLALTA20ABR2020-
            IF jTokenValue IN ['1', '2'] THEN BEGIN
                CASE jTokenValue OF
                    '2':
                        BEGIN
                            GlobalsCSWebServiceTable."Order Type" := GlobalsCSWebServiceTable."Order Type"::Takeaway;
                            GlobalsCSWebServiceTable.Actions := GlobalsCSWebServiceTable.Actions::"SetDelivery And Mail";
                        END;
                    '1':
                        GlobalsCSWebServiceTable."Order Type" := GlobalsCSWebServiceTable."Order Type"::Delivery;
                    ELSE
                        GlobalsCSWebServiceTable."Order Type" := GlobalsCSWebServiceTable."Order Type"::None;
                END;

                //IF MostrarPagos.Monto <> 0 THEN
                //    GlobalsCSWebServiceTable.Amount := MostrarPagos.Monto;

                //WVILLALTA 08.22-
                IF GlobalsCSWebServiceTable."Order Type" = GlobalsCSWebServiceTable."Order Type"::Delivery THEN BEGIN
                    GlobalsCSWebServiceTable."Value Text 1" := COPYSTR(GetValueAsText(JObject, 'latitude'), 1, 30);
                    GlobalsCSWebServiceTable."Value Text 1" += ',' + COPYSTR(GetValueAsText(JObject, 'longitude'), 1, 30);
                    //IF Phone = '72948098' THEN BEGIN
                    jTokenValue := COPYSTR(GetValueAsText(JObject, 'referencepoint'), 1, 250);
                    IF jTokenValue <> '' THEN
                        DELFUNCTION.POSNewLineFreeText(GlobalsCSWebServiceTable.LastSlipNo, 28, 'Referencia' + COPYSTR(jTokenValue, 1, 210), 2);
                    jTokenValue := 'Solicito ' + COPYSTR(GetValueAsText(JObject, 'typeofvoucher'), 1, 30) + '-' + COPYSTR(GetValueAsText(JObject, 'comment'), 1, 175);
                    IF (jTokenValue <> '') AND (jTokenValue <> '-') THEN
                        DELFUNCTION.POSNewLineFreeText(GlobalsCSWebServiceTable.LastSlipNo, 29, jTokenValue, 2);
                    CASE TenderTypeSetup_l."FSN Function in CC" OF
                        TenderTypeSetup_l."FSN Function in CC"::Change:
                            DELFUNCTION.POSNewLineFreeText(GlobalsCSWebServiceTable.LastSlipNo, 30, TenderTypeSetup_l.Description + ': Cambio solicitado $' + COPYSTR(GetValueAsText(JObject, 'moneyexchange'), 1, 10), 2);
                        ELSE
                            DELFUNCTION.POSNewLineFreeText(GlobalsCSWebServiceTable.LastSlipNo, 30, TenderTypeSetup_l.Description, 2)
                    END;

                    JsonToTableDeliveryNodes(COPYSTR(GetValueAsText(JObject, 'address'), 1, 250), 6, GlobalsCSWebServiceTable, 'DDIRECTION', 'F20');
                    JsonToTableDeliveryNodes(COPYSTR(GetValueAsText(JObject, 'beneficiaryName'), 1, 250), 1, GlobalsCSWebServiceTable, 'DNAME', 'F20');
                    //END;
                END;
                //WVILLALTA 08.22+

                GlobalsCSWebServiceTable."First Name" := UPPERCASE(COPYSTR(GetValueAsText(JToken, 'firstname'), 1, 30)); //WVILLALTA27ABR2020-
                GlobalsCSWebServiceTable."Last Name" := UPPERCASE(COPYSTR(GetValueAsText(JToken, 'lastname'), 1, 30));
                GlobalsCSWebServiceTable."Document Personal" := UPPERCASE(COPYSTR(GetValueAsText(JToken, 'personaldocument'), 1, 20));
                jTokenValue := COPYSTR(GetValueAsText(JToken, 'typedocument'), 1, 10);
                CASE jTokenValue OF
                    '1':
                        GlobalsCSWebServiceTable."Document Type" := GlobalsCSWebServiceTable."Document Type"::DUI;
                    ELSE
                        GlobalsCSWebServiceTable."Document Type" := GlobalsCSWebServiceTable."Document Type"::None;
                END; //WVILLALTA27ABR2020+
                jTokenValue := COPYSTR(GetValueAsText(JToken, 'store'), 1, 10);
                GlobalsCSWebServiceTable."Store Selected" := jTokenValue;
                IF POSTransaction.GET(pParameters."Current-RECEIPT") THEN
                    GlobalsCSWebServiceTable."Customer No." := POSTransaction."Customer No.";

                jTokenValue := COPYSTR(GetValueAsText(JToken, 'mail'), 1, 80);
                GlobalsCSWebServiceTable.Mail := jTokenValue;
                GlobalsCSWebServiceTable.INSERT;

                IF GlobalsCSWebServiceTable."Order Type" = GlobalsCSWebServiceTable."Order Type"::Takeaway THEN
                    InitLineFreeText(STRSUBSTNO(lText003, GlobalsCSWebServiceTable."Store Selected"), pParameters."Current-RECEIPT");
            END;
        END;*/
        /*IF (Phone <> '') AND POSTransaction.GET(pParameters."Current-RECEIPT") THEN BEGIN
            NewCustomerCode := '';
            NewCustomerCode := GetFirstCustomer(GlobalsCSWebServiceTable, POSTransaction, Phone);
            IF NewCustomerCode <> '' THEN BEGIN
                POSTransaction."Customer No." := NewCustomerCode;
                GlobalsCSWebServiceTable."Customer No." := NewCustomerCode;
                GlobalsCSWebServiceTable.MODIFY;
            END;
            Phone := DELCHR(Phone, '=', '-');
            Phone := DELCHR(Phone, '=', ' ');
            POSTransaction."Sell-to Contact No." := Phone;
            POSTransaction.MODIFY;
        END;
        COMMIT;
        SetCustomerNameInTrans(NewCustomerCode, POSTransaction);
        POSTransLine_l.RESET;                                                                    //WVILLALTA 9.20-
        POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", pParameters."Current-RECEIPT");
        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Payment);
        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Status", 0);
        POSTransLine_l.SETFILTER(POSTransLine_l.Number, '<>%1', '1');
        IF POSTransLine_l.FINDFIRST THEN
            //POSCommandExt.InsertByShowPayment(POSTransLine_l, MostrarPagos.BIN, MostrarPagos, POSTransaction);//WVILLALTA 9.20+

        IF SRFBANVALUE <> '' THEN BEGIN
                SRFBANVALUE := 'ECOMMERCE No.: ' + SRFBANVALUE;
                InitLineFreeText(SRFBANVALUE, pParameters."Current-RECEIPT");
            END;*/
    end;

    local procedure SearchCardLoyalty
    (
        pCustomerNo: Code[20];
        var pMemberShipCardTmp: Record "LSC Membership Card" temporary;
        pFirstOnly: Boolean;
        var pExists: Boolean
    )
    var
        MemberShipCard_l: Record "LSC Membership Card";
        MemberAccount_l: Record "LSC Member Account";
        Customer_l: Record Customer;
        ExitOnly: Boolean;
    begin
        pMemberShipCardTmp.Reset();
        pMemberShipCardTmp.DeleteAll;
        if Customer_l.Get(pCustomerNo) then begin
            MemberAccount_l.Reset();
            MemberAccount_l.SETCURRENTKEY("No.");
            MemberAccount_l.SetRange(MemberAccount_l."Linked To Customer No.", Customer_l."No.");
            if MemberAccount_l.Find('-') then
                REPEAT
                    MemberShipCard_l.Reset();
                    MemberShipCard_l.SETCURRENTKEY("Account No.", "Contact No.", Status);
                    MemberShipCard_l.SetRange(MemberShipCard_l."Account No.", MemberAccount_l."No.");
                    MemberShipCard_l.SetRange(MemberShipCard_l.Status, MemberShipCard_l.Status::Active);
                    MemberShipCard_l.SETFILTER(MemberShipCard_l."Last Valid Date", '>=%1', TODAY);
                    if MemberShipCard_l.Find('-') then
                        REPEAT
                            pMemberShipCardTmp.Init();
                            pMemberShipCardTmp := MemberShipCard_l;
                            ExitOnly := pMemberShipCardTmp.Insert();
                            if not pExists and ExitOnly then
                                pExists := TRUE;
                        UNTIL (MemberShipCard_l.NEXT = 0) or (ExitOnly and pFirstOnly);
                UNTIL (MemberAccount_l.NEXT = 0) or (ExitOnly and pFirstOnly);
        END;
    end;

    local procedure GetCustomerByKey(Cust: Record Customer): JsonObject
    var
        LSCMembershipCard: Record "LSC Membership Card";
        LSCMemberAcc: Record "LSC Member Account";
        JObject, district : JsonObject;
        DiscGroup: Code[20];
        FSNDate: Date;
        CountryRegion: Record "Country/Region";
    begin
        Clear(FSNDate);
        JObject.Add('No_', Cust."No.");
        JObject.Add('Name', Cust.Name);

        //* agregar DUI o Pasaporte
        if Cust."FSN DUI" <> '' then
            JObject.Add('NDocumento', Cust."FSN DUI")
        else
            JObject.Add('NDocumento', Cust."FSN Foreign document");

        JObject.Add('EMail', Cust."E-Mail");
        JObject.Add('VATNo', Cust."VAT Registration No.");

        if Cust."FSN Birthday" = FSNDate then
            Evaluate(FSNDate, '1753-01-01')
        else
            FSNDate := Cust."FSN Birthday";
        JObject.Add('FechaNacimiento', FSNDate);

        JObject.Add('Gender', Cust."FSN Gender".AsInteger());
        JObject.Add('PhoneNo_', Cust."Phone No.");
        JObject.Add('TelexNo_', Cust."Telex No.");
        JObject.Add('Address', Cust.Address);
        JObject.Add('City', Cust."Post Code");
        CountryRegion.Reset();
        IF CountryRegion.Get(Cust."Country/Region Code") THEN
            JObject.Add('Country', CountryRegion.Name)
        ELSE
            JObject.Add('Country', '');
        Jobject.Add('NRC', Cust."FSN NRC");
        JObject.Add('GIRO', Cust."DTE Activity Code");
        JObject.Add('_TaxID', Cust."DTE Tax ID Type".AsInteger());

        //* agregar clasificaion de cliente
        if (Cust."FSN Customer Type" = Cust."FSN Customer Type"::Person) and (Cust."FSN Foreign document" <> '') then
            JObject.Add('ClasificacionCliente', 2)
        else
            if Cust."FSN Customer Type" = Cust."FSN Customer Type"::Company then
                JObject.Add('ClasificacionCliente', 1)
            else
                JObject.Add('ClasificacionCliente', 0);

        JObject.Add('RetailCustomerGroup', Cust."LSC Retail Customer Group");
        JObject.Add('ReferenciaEBS', Cust."FSN EBS Reference");

        //* Da el Grupo de descuento
        DiscGroup := PreBillerExt.GetDiscGroupByCustomer(Cust."No.", Cust."Customer Disc. Group");
        JObject.Add('CustomerDiscGroup', DiscGroup);

        exit(JObject);
    end;

    local procedure GetMemberCardByKey(MemberCard: Record "LSC Membership Card"): JsonObject
    var
        JObject: JsonObject;
    begin
        JObject.Add('VIP', MemberCard."Card No.");
        JObject.Add('Club', MemberCard."Club Code");
        JObject.Add('Esquema', MemberCard."Scheme Code");
        JObject.Add('Beneficiario', MemberCard."FSN Beneficiary");
        JObject.Add('Vigencia', MemberCard."Last Valid Date");
        Case
            MemberCard.Status of
            0:
                JObject.Add('Estado', 'LIBRE');
            1:
                JObject.Add('Estado', 'ASIGNADO');
            2:
                begin
                    if MemberCard."Last Valid Date" >= Today then
                        JObject.Add('Estado', 'ACTIVO')
                    else
                        JObject.Add('Estado', 'INACTIVO');
                end;
            3:
                JObject.Add('Estado', 'BLOQUEADO');
        End;
        exit(JObject);
    end;
    #endregion
    #region [External Methods]

    procedure AddCustLine("Line No.": integer; var Response_Code: Text[10]; var Response_Text: Text) insertCustOk: Boolean
    var
        Custom_l: Record Customer;
    begin
        if not POSTransactionTB.Get(ReceiptNo_g) then begin
            Response_Code := '0071';
            Response_Text := StrSubstNo(gText001, ReceiptNo_g, POSTransactionTB.TABLECAPTION);
            exit(false);
        end;

        POSTransLineTB.init();
        POSTransLineTB.Validate("Receipt No.", POSTransactionTB."Receipt No.");
        POSTransLineTB.Validate("Entry Type", POSTransLineTB."Entry Type"::FreeText);
        POSTransLineTB.Validate("Line No.", "Line No.");
        POSTransLineTB.Validate("Store No.", POSTransactionTB."Store No.");
        POSTransLineTB.Validate("POS Terminal No.", POSTransactionTB."POS Terminal No.");
        POSTransLineTB.Validate("Text Type", POSTransLineTB."Text Type"::"Cust. Text");
        if POSTransactionTB."Customer No." <> '' then
            if Custom_l.Get(POSTransactionTB."Customer No.") then begin
                POSTransLineTB.Description := CopyStr('Cliente(' + POSTransactionTB."Customer Disc. Group" + ') ' + Custom_l.Name, 1, MAXSTRLEN(POSTransLineTB.Description));
                POSTransLineTB.Validate("Card/Customer/Coup.Item No", Custom_l."No.");
            end;
        if not POSTransLineTB.insert(true) then begin
            Response_Code := '0072';
            Response_Text := StrSubstNo(gText017, GetLASTERRorTEXT);
            exit(false);
        end;

        exit(true);
    end;

    procedure AddLinePosExch
    (
        _CurrentLine: integer;
        _ItemNo_: Code[20];
        _UnitOfMeasure: Code[20];
        _Qty: integer;
        _EntryType: integer;
        _CodeDescription: Code[20];
        var Response_Code: Text[10];
        var Response_Text: Text
    ): Boolean;
    var
        POSExchTrans: Record "FSN POS Exchange Transaction";
        POSExchTrans2: Record "FSN POS Exchange Transaction";
        POSExchSetup: Record "FSN POS Exchange Setup";
        POSExchLinks: Record "FSN POS Exchange Item Link";
        Barcode_l: Record "LSC Barcodes";
        BarcodeCode: Code[20];
        Ok_: Boolean;
        lText001: Label 'No se puede insertar Linea de canje, ya existe para esta transaccion %1 Linea %2 ';
        lText002: Label 'Codigo descripcioncanje PV %1 no valido';
        lText003: Label 'Item %1  UM %2 no tiene configurado barra';
        lText004: Label 'Error en registro. Los canjes deben tener definido un cliente';
        lText005: Label 'No se pudo registrar, error en inSERT. %1';
        lText006: Label 'Canje %1 valido solo para cliente %2';
    begin
        if (_EntryType <> 102) then exit;

        if not (POSTransactionTB."Customer No." <> '') then begin
            Response_Text := lText004;
            Response_Code := '6004';
            exit(false);
        end;

        if POSExchTrans2.Get(POSTransactionTB."Receipt No.", 0, _CurrentLine, POSTransactionTB."Store No.", POSTransactionTB."POS Terminal No.") then begin
            Response_Text := StrSubstNo(lText001, POSTransactionTB."Receipt No.", _CurrentLine);
            Response_Code := '6001';
            exit(false);
        end;

        Ok_ := FALSE;
        POSExchLinks.Reset();
        POSExchLinks.SetRange(POSExchLinks."Item No.", _ItemNo_);
        POSExchLinks.SetRange(POSExchLinks."Unit of Measure", _UnitOfMeasure);
        if POSExchLinks.FinDSET then
            repeat
                if POSExchSetup.Get(POSExchLinks."POS Exchange No.") then
                    if POSExchSetup."POS Exchange Code" = _CodeDescription then
                        if ((POSExchSetup."Starting Date" = 0D) or (POSExchSetup."Starting Date" <= TODAY)) and
                          ((POSExchSetup."Ending Date" = 0D) or (POSExchSetup."Ending Date" >= TODAY)) then
                            Ok_ := true;
            until (POSExchLinks.NEXT = 0) or Ok_;

        if not Ok_ then begin
            Response_Text := StrSubstNo(lText002, _CodeDescription);
            Response_Code := '6002';
            exit(false);
        end;

        if POSExchSetup."Cust. Disc. Group Filter" <> '' then
            if POSExchSetup."Cust. Disc. Group Filter" <> POSTransactionTB."Customer Disc. Group" then begin
                Response_Text := StrSubstNo(lText006, POSExchSetup.Description, POSExchSetup."Cust. Disc. Group Filter");
                Response_Code := '6002';
                exit(false);
            end;

        BarcodeCode := '';
        Barcode_l.Reset();
        Barcode_l.SetRange(Barcode_l."Item No.", _ItemNo_);
        Barcode_l.SetRange(Barcode_l."Unit of Measure Code");
        if not Barcode_l.FindFirst() then begin
            Response_Text := StrSubstNo(lText003, POSExchTrans2.GetItemDescription(_ItemNo_), _UnitOfMeasure);
            Response_Code := '6003';
            exit(false);
        end;
        BarcodeCode := Barcode_l."Barcode No.";

        POSExchTrans.init();
        POSExchTrans."Receipt No." := POSTransactionTB."Receipt No.";
        POSExchTrans."Transaction No." := 0;
        POSExchTrans."Line No." := _CurrentLine;
        POSExchTrans."Store No." := POSTransactionTB."Store No.";
        POSExchTrans."POS Terminal No." := POSTransactionTB."POS Terminal No.";
        POSExchTrans."Barcode No." := BarcodeCode;
        POSExchTrans."Item No." := _ItemNo_;
        POSExchTrans."Unit of Measure" := _UnitOfMeasure;
        POSExchTrans.Quantity := _Qty;
        POSExchTrans.Status := POSExchTrans.Status::Open;
        POSExchTrans."Transfer order No." := '';
        POSExchTrans."Staff ID" := '';
        POSExchTrans."Sales Staff" := POSSession.StaffID;
        POSExchTrans."Customer No." := POSTransactionTB."Customer No.";
        POSExchTrans."Customer Sub Code" := '';
        POSExchTrans."Transaction Date" := TODAY;
        POSExchTrans."origin Line Detected" := 0;
        POSExchTrans."POS Exchange No." := POSExchSetup."No.";
        POSExchTrans."Posting Date" := 0D;
        POSExchTrans."Use inventory" := POSExchSetup."Use inventory";
        POSExchTrans.Request := POSExchTrans.Request::None;
        POSExchTrans."Autorization Type" := 0;
        if POSExchSetup."Authorization Type" = POSExchSetup."Authorization Type"::WebPage then
            POSExchTrans."Autorization Type" := POSExchTrans."Autorization Type"::WebPage;
        if POSExchSetup."Control Type" = POSExchSetup."Control Type"::DeliveryToVendor then
            POSExchTrans.Request := POSExchTrans.Request::DeliveryToVendor;
        POSExchTrans."Posting Date" := 0D;
        POSExchTrans."Use inventory" := POSExchSetup."Use inventory";

        if not POSExchTrans.insert() then begin
            Response_Text := StrSubstNo(lText005, GetLASTERRorTEXT);
            Response_Code := '6005';
            exit(false);
        END;

        exit(true);
    end;

    procedure AdjustmentSaleRegister
    (
        BarcodeNo: Code[20];
        ItemNo: Code[20];
        LocationCode: Code[10];
        Qty: integer;
        UOM: Code[10];
        Staff: Code[10];
        var Response_Code: Text[10];
        var Response_Text: Text
    ) Result_: Boolean
    var
        Item_l: Record item;
        Barcode_l: Record "LSC Barcodes";
        ItemUM_l: Record "Unit of Measure";
        Staff_l: Record "LSC Staff";
        ReplenishmentSalesHistoryAdjLines: Record "FSN Replen. Sales Adj. Line";
        _ReplenSalesAdjLine: Record "FSN Replen. Sales Adj. Line";
        lText001: Label 'Valor %1 no existe en tabla %2';
        lText002: Label 'Item %1 no corresponde a la barra %2 ';
        lText003: Label 'La unidad de medida %1 del producto %2 no existe';
        lText004: Label 'No se pudo registrar el Ajuste venta. %1';
    begin
        Response_Code := '0000';
        Response_Text := gText020;
        ItemUM_l.Reset();
        if not Barcode_l.Get(BarcodeNo) then begin
            Response_Code := '0250';
            Response_Text := STRSUBSTNO(lText001, BarcodeNo, Barcode_l.TABLECAPTION);
            EXIT(FALSE);
        END;
        if not Item_l.Get(ItemNo) then begin
            Response_Code := '0251';
            Response_Text := STRSUBSTNO(lText001, ItemNo, Item_l.TABLECAPTION);
            EXIT(FALSE);
        END;
        if Barcode_l."Item No." <> ItemNo then begin
            Response_Code := '0252';
            Response_Text := STRSUBSTNO(lText002, ItemNo, BarcodeNo);
            EXIT(FALSE);
        END;
        if not ItemUM_l.Get(UOM) then begin
            Response_Code := '0253';
            Response_Text := STRSUBSTNO(lText002, UOM, Item_l.Description);
            EXIT(FALSE);
        END;
        if not Staff_l.Get(Staff) then begin
            Response_Code := '0255';
            Response_Text := STRSUBSTNO(gText001, Staff, Staff_l.TABLECAPTION);
            EXIT(FALSE);
        END;
        Clear(ReplenishmentSalesHistoryAdjLines);
        ReplenishmentSalesHistoryAdjLines.VALIDATE("Barcode No.", BarcodeNo);
        ReplenishmentSalesHistoryAdjLines."Location Code" := LocationCode;
        ReplenishmentSalesHistoryAdjLines.VALIDATE("Item No.", ItemNo);
        ReplenishmentSalesHistoryAdjLines.VALIDATE(Quantity, Qty);
        ReplenishmentSalesHistoryAdjLines."Unit of Measure" := UOM;
        ReplenishmentSalesHistoryAdjLines.StaffID := Staff;
        ReplenishmentSalesHistoryAdjLines.Date := Today;
        ReplenishmentSalesHistoryAdjLines.Aprobada := true;

        if not ReplenishmentSalesHistoryAdjLines.Insert(TRUE) then begin
            Response_Code := '0254';
            Response_Text := STRSUBSTNO(lText002, GetLASTERRorTEXT);
            EXIT(FALSE);
        END;
        Response_Text := gText021;
        EXIT(TRUE);
    end;

    procedure CompressArrayProcess();
    begin
        CompressTransLine.Reset();
        CompressTransLine.DeleteAll();

        POSTransLineTB.Reset();
        POSTransLineTB.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
        POSTransLineTB.SetRange(POSTransLineTB."Receipt No.", POSTransactionTB."Receipt No.");
        if gRequestFromID in ['DELIVERY', 'POS'] then//ECOMMERCE-
            POSTransLineTB.SETFILTER(POSTransLineTB."Entry Type", '%1|%2|%3', POSTransLineTB."Entry Type"::Item, POSTransLineTB."Entry Type"::PerDiscount, POSTransLineTB."Entry Type"::Coupon)
        else
            POSTransLineTB.SetRange(POSTransLineTB."Entry Type", POSTransLineTB."Entry Type"::Item);//ECOMMERCE+

        POSTransLineTB.SetRange(POSTransLineTB."Entry Status", POSTransLineTB."Entry Status"::" ");
        if POSTransLineTB.Find('-') then
            repeat
                if POSTransLineTB."Entry Type" = POSTransLineTB."Entry Type"::Item then begin
                    CompressTransLine.Reset();
                    CompressTransLine.SetRange(CompressTransLine."Receipt No.", POSTransLineTB."Receipt No.");
                    CompressTransLine.SetRange(CompressTransLine.Number, POSTransLineTB.Number);
                    CompressTransLine.SetRange(CompressTransLine."Unit of Measure", POSTransLineTB."Unit of Measure");
                    if ValidateItemVariants(POSTransLineTB.Number) then//28981
                        CompressTransLine.SetRange(CompressTransLine."Line No.", POSTransLineTB."Line No.");//28981
                    CompressTransLine.SetRange("Lot No.", POSTransLineTB."Lot No.");
                    if not CompressTransLine.FindFirst() then begin
                        CompressTransLine.Init();
                        CompressTransLine."Receipt No." := POSTransLineTB."Receipt No.";
                        CompressTransLine."Line No." := POSTransLineTB."Line No.";
                        CompressTransLine.Number := POSTransLineTB.Number;
                        CompressTransLine."Unit of Measure" := POSTransLineTB."Unit of Measure";
                        CompressTransLine.Quantity := POSTransLineTB.Quantity;
                        CompressTransLine.Amount := POSTransLineTB.Amount;
                        CompressTransLine.Price := POSTransLineTB.Price;
                        CompressTransLine.Description := POSTransLineTB.Description;
                        CompressTransLine."Entry Type" := POSTransLineTB."Entry Type";
                        CompressTransLine."Discount %" := POSTransLineTB."Discount %";
                        CompressTransLine."Discount Amount" := POSTransLineTB."Discount Amount";
                        CompressTransLine."Lot No." := POSTransLineTB."Lot No.";
                        CompressTransLine."Expiration Date" := POSTransLineTB."Expiration Date";
                        CompressTransLine.Insert();
                    end else begin
                        CompressTransLine.Quantity += POSTransLineTB.Quantity;
                        CompressTransLine.Amount += POSTransLineTB.Amount;
                        CompressTransLine."Discount Amount" += POSTransLineTB."Discount Amount";
                        CompressTransLine."Discount %" := CompressTransLine."Discount Amount" / (CompressTransLine.Price * CompressTransLine.Quantity);
                        CompressTransLine."Discount %" := Round(CompressTransLine."Discount %" * 100, 0.1);
                        CompressTransLine.Modify();
                    end;
                end else begin
                    CompressTransLine.Init();
                    CompressTransLine := POSTransLineTB;
                    CompressTransLine.Insert();
                end;
            until POSTransLineTB.NEXT = 0;
    end;

    procedure ValidateItemVariants(ItemCode: Code[20]): Boolean
    var
        TableSpecInfocode: Record "LSC Table Specific Infocode";
        LSCInfocode: Record "LSC Infocode";
    begin

        TableSpecInfocode.SetCurrentKey("Table ID", Value, "Infocode Code");
        TableSpecInfocode.SetRange(TableSpecInfocode."Table ID", Database::Item);
        TableSpecInfocode.SETRANGE(Value, ItemCode);
        TableSpecInfocode.SETRANGE("Infocode Code", ItemCode);
        if TableSpecInfocode.FindFirst() then begin
            if LSCInfocode.get(TableSpecInfocode."Infocode Code") then begin
                if LSCInfocode.Prompt = 'VARIANTES' then
                    exit(true)
                else
                    exit(false);

            end else
                exit(false);
        end else
            exit(false);
    end;

    procedure CouponList
    (
        Arr_ItemNo: array[50] of Code[10];
        Store: Code[10];
        POSTerminal: Code[10];
        MembershipCard: Text[100];
        var ArrCouponCode: array[50] of Code[10];
        var ArrDescription: array[50] of Text[50];
        var ArrDescription2: array[50] of Text[50];
        var ArrStatus: array[50] of Text[25];
        var Arrinfocode: array[50] of Code[10]
    )
    var
        CouponHeader: Record "LSC Coupon Header";
        CouponLine: Record "LSC Coupon Line";
        PeriodicDiscountLine: Record "LSC Periodic Discount Line";
        StorePriceGroup: Record "LSC Store Price Group";
        Item_l: Record Item;
        SpecialGroupLink: Record "LSC Item/Special Group Link";
        RetailUtil: Codeunit "LSC Retail Price Utils";
        ArrCouponList2: array[75, 4] of Text[50];
        FilterClubCode: Code[10];
        FilterSchemeCode: Code[10];
        FilterCustomerDiscGroup: Code[10];
        index: integer;
        ArrayLen_: integer;
    begin
        ArrayLen_ := ARRAYLEN(Arr_ItemNo);

        ItemsinTransactionTEMP.Reset();
        ItemsinTransactionTEMP.DeleteAll;
        CouponHeaderTEMP.Reset();
        CouponHeaderTEMP.DeleteAll;
        index := 1;

        WHILE index <= ArrayLen_ DO begin
            if Item_l.Get(Arr_ItemNo[index]) then
                if not ItemsinTransactionTEMP.Get(Item_l."No.") then begin
                    ItemsinTransactionTEMP.Init();
                    ItemsinTransactionTEMP."No." := Item_l."No.";
                    ItemsinTransactionTEMP."Item Category Code" := Item_l."Item Category Code";
                    ItemsinTransactionTEMP."LSC Retail Product Code" := Item_l."LSC Retail Product Code";
                    ItemsinTransactionTEMP.Insert();
                END;
            index += 1;
        END;

        FilterClubCode := '';
        FilterSchemeCode := '';
        FilterCustomerDiscGroup := '';
        if MembershipCard <> '' then
            ApplyGetMemberType(MembershipCard, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);

        if ItemsinTransactionTEMP.FinDFIRST then
            REPEAT
                CouponLine.Reset();
                CouponLine.SETCURRENTKEY("Coupon Type", "Coupon Header Status", "Coupon Code", "List Type", Type, "No.");
                CouponLine.SetRange(CouponLine."Coupon Type", CouponLine."Coupon Type"::"Store Coupon");
                CouponLine.SetRange(CouponLine."Coupon Header Status", CouponLine."Coupon Header Status"::Enabled);
                CouponLine.SetRange(CouponLine."List Type", CouponLine."List Type"::Use);
                CouponLine.SetRange(CouponLine.Type, CouponLine.Type::Item);
                CouponLine.SetRange(CouponLine."No.", ItemsinTransactionTEMP."No.");
                if CouponLine.FinDSET then
                    REPEAT
                        if not CouponLine.Exclude then
                            ApplyCouponByCouponLine(CouponLine."Coupon Code", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
                    UNTIL CouponLine.NEXT = 0;

                CouponLine.SetRange(CouponLine.Type, CouponLine.Type::"Item Category");
                CouponLine.SetRange(CouponLine."No.", ItemsinTransactionTEMP."Item Category Code");
                if CouponLine.FinDSET then
                    REPEAT
                        if not CouponLine.Exclude then
                            ApplyCouponByCouponLine(CouponLine."Coupon Code", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
                    UNTIL CouponLine.NEXT = 0;

                CouponLine.SetRange(CouponLine.Type, CouponLine.Type::"Product Group");
                CouponLine.SetRange(CouponLine."No.", ItemsinTransactionTEMP."LSC Retail Product Code");
                if CouponLine.FinDSET then
                    REPEAT
                        if not CouponLine.Exclude then
                            ApplyCouponByCouponLine(CouponLine."Coupon Code", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
                    UNTIL CouponLine.NEXT = 0;

                CouponLine.SetRange(Type, CouponLine.Type::"Special Group");
                CouponLine.SetRange(Exclude, FALSE);
                CouponLine.SETFILTER("No.", '<>%1', '');
                if CouponLine.FinDSET then
                    REPEAT
                        if SpecialGroupLink.Get(ItemsinTransactionTEMP."No.", CouponLine."No.") then
                            ApplyCouponByCouponLine(CouponLine."Coupon Code", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
                    UNTIL CouponLine.NEXT = 0;

                PeriodicDiscountLine.Reset();
                PeriodicDiscountLine.SETCURRENTKEY("Offer No.", Type, "No.", "Variant Code", "Unit of Measure",
                  "Prod. Group Category");
                PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Status, PeriodicDiscountLine.Status::Enabled);
                PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Exclude, FALSE);
                PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Type, PeriodicDiscountLine.Type::Item);
                PeriodicDiscountLine.SetRange(PeriodicDiscountLine."No.", ItemsinTransactionTEMP."No.");
                if PeriodicDiscountLine.FinDSET then
                    REPEAT
                        ApplyCouponByPerDiscLine(PeriodicDiscountLine."Offer No.", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
                    UNTIL PeriodicDiscountLine.NEXT = 0;

                PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Type, PeriodicDiscountLine.Type::"Product Group");
                PeriodicDiscountLine.SetRange(PeriodicDiscountLine."No.", ItemsinTransactionTEMP."LSC Retail Product Code");
                if PeriodicDiscountLine.FinDSET then
                    REPEAT
                        ApplyCouponByPerDiscLine(PeriodicDiscountLine."Offer No.", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
                    UNTIL PeriodicDiscountLine.NEXT = 0;

                PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Type, PeriodicDiscountLine.Type::"Item Category");
                PeriodicDiscountLine.SetRange(PeriodicDiscountLine."No.", ItemsinTransactionTEMP."Item Category Code");
                if PeriodicDiscountLine.FinDSET then
                    REPEAT
                        ApplyCouponByPerDiscLine(PeriodicDiscountLine."Offer No.", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
                    UNTIL PeriodicDiscountLine.NEXT = 0;

                PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Type, PeriodicDiscountLine.Type::"Special Group");
                PeriodicDiscountLine.SETFILTER(PeriodicDiscountLine."No.", '<>%1', '');
                if PeriodicDiscountLine.FinDSET then
                    REPEAT
                        if SpecialGroupLink.Get(ItemsinTransactionTEMP."No.", PeriodicDiscountLine."No.") then
                            ApplyCouponByPerDiscLine(PeriodicDiscountLine."Offer No.", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
                    UNTIL PeriodicDiscountLine.NEXT = 0;

            UNTIL ItemsinTransactionTEMP.NEXT = 0;

        CouponLine.Reset();
        CouponLine.SETCURRENTKEY("Coupon Type", "Coupon Header Status", "Coupon Code", "List Type", Type, "No.");
        CouponLine.SetRange(CouponLine."Coupon Type", CouponLine."Coupon Type"::"Store Coupon");
        CouponLine.SetRange(CouponLine."Coupon Header Status", CouponLine."Coupon Header Status"::Enabled);
        CouponLine.SetRange(CouponLine."List Type", CouponLine."List Type"::Use);
        CouponLine.SetRange(CouponLine.Type, CouponLine.Type::All);
        if CouponLine.FinDSET then
            REPEAT
                ApplyCouponByCouponLine(CouponLine."Coupon Code", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
            UNTIL CouponLine.NEXT = 0;

        PeriodicDiscountLine.Reset();
        PeriodicDiscountLine.SETCURRENTKEY("Offer No.", Type, "No.", "Variant Code", "Unit of Measure",
          "Prod. Group Category");
        PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Status, PeriodicDiscountLine.Status::Enabled);
        PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Exclude, FALSE);
        PeriodicDiscountLine.SetRange(PeriodicDiscountLine.Type, PeriodicDiscountLine.Type::All);
        if PeriodicDiscountLine.FinDSET then
            REPEAT
                ApplyCouponByPerDiscLine(PeriodicDiscountLine."Offer No.", Store, FilterClubCode, FilterSchemeCode, FilterCustomerDiscGroup);
            UNTIL PeriodicDiscountLine.NEXT = 0;

        CLEAR(ArrCouponCode);
        CLEAR(ArrDescription);
        CLEAR(ArrDescription2);
        CLEAR(ArrStatus);

        index := 1;
        CouponHeaderTEMP.Reset();
        if not CouponHeaderTEMP.ISEMPTY then
            if CouponHeaderTEMP.FinDSET then
                REPEAT
                    ArrCouponCode[index] := CouponHeaderTEMP.Code;
                    ArrDescription[index] := CouponHeaderTEMP.Description;
                    ArrDescription2[index] := CouponHeaderTEMP."Description 2";
                    ArrStatus[index] := 'Habilitado';
                    Arrinfocode[index] := CouponHeaderTEMP."FSN infocode";
                    index += 1;
                UNTIL (CouponHeaderTEMP.NEXT = 0) or (index >= 14);

        CouponHeaderTEMP.Reset();
        CouponHeaderTEMP.DeleteAll;
        ItemsinTransactionTEMP.Reset();
        ItemsinTransactionTEMP.DeleteAll;
    end;

    procedure CustomCheckMemberCard(CI: Text; REC: Record "LSC POS Transaction"): Boolean;
    var
        MembershipCard: Record "LSC Membership Card";
        MemberScheme: Record "LSC Member Scheme";
        POSTransLine2: Record "LSC POS Trans. Line";
        DT: Record "LSC POS Trans. Per. Disc. Type";
        OfferPosCalc: Record "LSC Offer Pos Calculation";
        lPOSTransPerDisc: Record "LSC POS Trans. Per. Disc. Type";
        PosSetup: Record "LSC POS Hardware Profile";
        MemberAccount_g: Record "LSC Member Account";
        MemberClub_g: Record "LSC Member Club";
        MemberContact_g: Record "LSC Member Contact";
        Customer: Record Customer;
        PosVisualProfile: Record "LSC POS Menu Profile";
        MemberCardMnt: Codeunit "LSC Member Card Management";
        PosPrice: Codeunit "LSC POS Print Utility";
        PosFunc: Codeunit "LSC POS Functions";
        POSTRANS: Codeunit "LSC POS Transaction";
        PosOfferExt: Codeunit "LSC POS Offer Ext. Utility";
        OfferType: Option;
        ErrorText_l: Text;
        Currinput: Text;
        STATE: Code[10];
        STATE_SALES: Code[10];
        NewPriceGroup: Code[10];
        NewCustDiscGroup: Code[10];
        lPrice: Decimal;
        lQty: Decimal;
        RecalcNeeded: Boolean;
        PromotionForMember: Boolean;
        ProcessError_l: Boolean;
        OnlySelectCustomer: Boolean;
    begin
        Currinput := CI;
        /*if PosSetup."Use Non-Payment Track Handling" then
            Currinput := EditNonPaymentTrack(Currinput);*/

        if (STATE <> STATE_SALES) or (POSGUI.GetCurrMenu(0) <> PosVisualProfile."Sales Menu") then begin
            POSTRANS.SetPOSState(STATE_SALES);
            POSTRANS.SetFunctionMode('ITEM');
            POSTRANS.SelectDefaultMenu;
            REC."Transaction Type" := REC."Transaction Type"::Sales;
        END;

        REC.Get(REC."Receipt No.");
        if REC."New Transaction" then
            POSTRANS.SalePressed(FALSE);
        lPOSTransPerDisc.Reset();
        lPOSTransPerDisc.SetRange("Receipt No.", REC."Receipt No.");
        lPOSTransPerDisc.SetRange(lPOSTransPerDisc.DiscType, lPOSTransPerDisc.DiscType::Coupon);
        lPOSTransPerDisc.DeleteAll(TRUE);

        /*if not PosFunc.GetMemberShipCardinfo(MembershipCard) then
            EXIT(FALSE);
            
        if not PosFunc.GetMemberAccountinfo(MemberAccount_g) then
            EXIT(FALSE);

        if not PosFunc.GetMemberClubinfo(MemberClub_g) then
            EXIT(FALSE);

        if not PosFunc.GetCurrMemberContact(MemberContact_g) then
            EXIT(FALSE);*/

        REC."Starting Point Balance" := MemberAccount_g.Balance + MemberAccount_g."Unprocessed Points";

        NewCustDiscGroup := PreBillerExt.GetValidCustDiscGroup(MembershipCard."Card No.");
        NewPriceGroup := GetValidPriceGroup(MembershipCard."Card No.");

        if NewCustDiscGroup <> '' then
            if REC."Customer Disc. Group" <> NewCustDiscGroup then begin
                RecalcNeeded := TRUE;
                REC."Customer Disc. Group" := NewCustDiscGroup;
            END;
        if NewPriceGroup <> '' then
            if NewPriceGroup <> REC."Price Group Code" then begin
                RecalcNeeded := TRUE;
                REC."Member Price Group" := NewPriceGroup;
            END;

        REC."Member Card No." := MembershipCard."Card No.";
        if (MemberAccount_g."Linked To Customer No." <> '') and Customer.Get(MemberAccount_g."Linked To Customer No.") then begin
            OnlySelectCustomer := TRUE;
            POSTRANS.ProcessCustomer(FALSE);
            OnlySelectCustomer := FALSE;
        END;

        REC.MODifY;
        //PromotionForMember := PosPrice.IsPromotionForMember(REC);
        /* POSTransLine2.Reset();
         POSTransLine2.SetRange("Receipt No.", REC."Receipt No.");
         POSTransLine2.SetRange("Entry Type", POSTransLine2."Entry Type"::Item);
         if POSTransLine2.FinD('-') then
             REPEAT
                 if PromotionForMember or RecalcNeeded then begin
                     lPrice := POSTransLine2.Price;
                     lQty := POSTransLine2.Quantity;
                     PosPrice.insertTransDiscPercent(POSTransLine2, 0, DT.DiscType::"Periodic Disc.", '');
                     POSTransLine2."Promotion No." := '';
                     POSTransLine2."Mix & Match Line No." := 0;
                     PosPrice.insertTransDiscAmount(POSTransLine2, 0, DT.DiscType::"Periodic Disc.", '');
                     CLEAR(OfferPosCalc);
                     OfferPosCalc.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                     OfferPosCalc.SetRange("Trans. Line No.", POSTransLine2."Line No.");
                     OfferPosCalc.DeleteAll;
                     if not POSTransLine2."Price Change" then //LS7.1-27
                         PosPrice.CalcPrice(POSTransLine2, FALSE);
                     if (lPrice <> POSTransLine2.Price) then begin
                         POSTransLine2.VALIDATE(Quantity, lQty);
                         POSTransLine2.MODifY(TRUE);
                     END;
                 END;
                 PosPrice.initGlobals(POSTransLine2, TRUE);
                 PosPrice.FindPeriodicOffers(POSTransLine2);
                 POSTransLine2.MODifY(TRUE);
             UNTIL POSTransLine2.NEXT = 0;

         PosPrice.CalcPeriodicOnTotalPressed(REC);
         PosFunc.RecalcSlip(REC);

         if not PosFunc.IsinPaymentState then
             PosOfferExt.ReCalcLinePreTotal(REC);

         if PosFunc.IsinPaymentState then
             PosOfferExt.ReCalcOfferSeq(REC, OfferType::"Total Discount");*/
        COMMIT;

        //Description := MembershipCard."Club Code" + ' ' + MembershipCard."Scheme Code";
        //Description2 := Currinput;
        EXIT(TRUE);
    end;

    procedure CustomerManagement
    (
        _StoreNo: Code[10];
        _POSTerminal: Code[10];
        var _Code: Code[20];
        _Name: Text[50];
        _DUI: Code[20];
        _TaxID: Integer;
        _Phone: Text[30];
        _Phone_2: Text[20];
        _Birthday: Date;
        _ClientType: integer;
        _Gender: integer;
        _Email: Text[80];
        _Address: Text[250];
        _City: Text[30];
        _NIT: Text[20];
        _NRC: Text[30];
        _Giro: Text[120];
        _ExtrangeroNo_: Code[20];
        _Country: Code[20];
        var Response_Code: Text[10];
        var Response_Text: Text;
        _Action: integer;
        _Trigger: Boolean
    ) CustCreateNewOk: Code[20]
    var
        PAGECustomerCard: Page "Customer Card";
        POSTerminalREC: Record "LSC POS Terminal";
        POSStoreREC: Record "LSC Store";
        CustomerDefault: Record Customer;
        postcode: Record "Post Code";
        RestricOption_: Option Normal,NameOnly,ExcpName,All;
        FunctionalityProfile: Code[10];
        lText001: Label 'Perfil Funcionalidad no existe para Tienda %1 - Terminal %2';
        lText002: Label 'Perfil Funcionalidad no existe %1';
        lText003: Label 'Nada que hacer';
        lText004: Label 'Cliente por defecto no configurado en Perfil Funcionalidad %1';
        lText005: Label 'Cliente configurado en perfil funcionalidad ID %1 no existe';
        lText006: Label 'Cliente ID %1 no existe';
        lText007: Label 'Cliente modificado con exito!';
        lText008: Label 'Cliente registrado con exito!';
        lText009: Label 'El tipo de cliente solo puede ser Persona (0) ó Empresa (1). Esto es un error de programación.';
        lText010: Label 'El Genero solo puede ser Masculino(1) ó Femenino(2) o bien ninguno(0).';
        Country: Record "Country/Region";
    begin

        //TODO: colocar aca la validacion

        GLOBALLANGUAGE(2058);
        FunctionalityProfile := '';
        Clear(PosFuncProfile);
        Clear(gCustomer);
        Response_Code := '0000';
        Response_Text := lText003;
        if not (_Action in [1, 2]) then
            exit('');

        if ((_Code = '') or (_Code = ' ')) and (_Action = 2) then
            exit('');

        if (_Code <> '') and (_Action = 1) then
            exit('');

        if not (_ClientType in [0, 1]) then begin
            Response_Code := '2200';
            Response_Text := lText009;
            exit('');
        end;

        if not (_Gender in [0, 1, 2]) then begin
            Response_Code := '2300';
            Response_Text := lText010;
            exit('');
        end;

        if _Action = 1 then begin
            if POSTerminalREC.Get(_POSTerminal) then
                if POSTerminalREC."Functionality Profile" <> '' then
                    FunctionalityProfile := POSTerminalREC."Functionality Profile";
            if FunctionalityProfile = '' then
                if POSStoreREC.Get(_StoreNo) then
                    if POSStoreREC."Functionality Profile" <> '' then
                        FunctionalityProfile := POSStoreREC."Functionality Profile";

            if FunctionalityProfile = '' then begin
                Response_Code := '2000';
                Response_Text := STRSUBSTNO(lText001, _StoreNo, _POSTerminal);
                exit('');
            end;

            if not PosFuncProfile.Get(FunctionalityProfile) then begin
                Response_Code := '2001';
                Response_Text := STRSUBSTNO(lText002, FunctionalityProfile);
                exit('');
            end;

            if PosFuncProfile."New Customer Defaults" = '' then begin
                Response_Code := '2002';
                Response_Text := STRSUBSTNO(lText004, FunctionalityProfile);
                exit('');
            end;

            if not CustomerDefault.Get(PosFuncProfile."New Customer Defaults") then begin
                Response_Code := '2003';
                Response_Text := STRSUBSTNO(lText005, FunctionalityProfile);
                exit('');
            end;

            if _Trigger then begin//For Custom New
                if not CustomerValidateData(PosFuncProfile."New Customer Defaults", _DUI, _NIT, _NRC, _ExtrangeroNo_, _Giro, _Birthday,
                  _ClientType, TRUE, RestricOption_, Response_Code, Response_Text) then
                    EXIT('');
            END;
        END ELSE begin
            if not gCustomer.Get(_Code) then begin
                Response_Code := '2004';
                Response_Text := STRSUBSTNO(lText006, _Code);
                EXIT('');
            END;
            if _Trigger then begin//For Custom Edit
                if not CustomerValidateData(_Code, _DUI, _NIT, _NRC, _ExtrangeroNo_, _Giro, _Birthday, _ClientType, FALSE,
                   RestricOption_, Response_Code, Response_Text) then
                    EXIT('');
            END;
        END;
        COMMIT;
        gCustomer.LOCKTABLE;

        if _Action = 2 then
            gCustomer.Get(_Code)
        ELSE begin
            gCustomer.init();
            gCustomer := CustomerDefault;
        END;

        if not isEditableCustomer(gCustomer) then begin
            Response_Code := '0100';
            Response_Text := 'El cliente no puede ser editado';
            exit('');
        end;

        if not (RestricOption_ in [RestricOption_::ExcpName, RestricOption_::All]) then
            gCustomer.VALIDATE(Name, UPPERCASE(_Name));

        if not (RestricOption_ in [RestricOption_::NameOnly, RestricOption_::All]) then begin
            gCustomer."FSN DUI" := _DUI;
            case _TaxID of
                36:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::NIT;
                13:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::DUI;
                37:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::Otros;
                3:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::Pasaporte;
                2:
                    gCustomer."DTE Tax ID Type" := gCustomer."DTE Tax ID Type"::"Carnet de Residente";
            end;
            gCustomer."Phone No." := _Phone;
            gCustomer."Telex No." := _Phone_2;
            if DATE2DMY(_Birthday, 3) = 1753 then
                gCustomer."FSN Birthday" := 0D
            ELSE
                gCustomer."FSN Birthday" := _Birthday;
            case _ClientType of
                0:
                    gCustomer."FSN Customer Type" := gCustomer."FSN Customer Type"::Person;
                1:
                    gCustomer."FSN Customer Type" := gCustomer."FSN Customer Type"::Company;
            end;
            case _Gender of
                0:
                    gCustomer."FSN Gender" := gCustomer."FSN Gender"::" ";
                1:
                    gCustomer."FSN Gender" := gCustomer."FSN Gender"::Male;
                2:
                    gCustomer."FSN Gender" := gCustomer."FSN Gender"::Female;

            end;
            //gCustomer."Contact Type" := _ClientType;
            //gCustomer."FSN Gender" := _Gender;
            gCustomer."E-Mail" := _Email;
            gCustomer.Address := _Address;
            //! quedo obsoleto 
            //gCustomer.City := _City; 
            postcode.SetRange(Code, _City);
            if postcode.FindFirst then
                gCustomer.Validate("Post Code", postcode.Code);
            Country.Reset();
            Country.SetRange(Name, _Country);
            if Country.FindFirst then
                gCustomer."Country/Region Code" := Country.Code;

            gCustomer."VAT Registration No." := _NIT;
            gCustomer."FSN NRC" := _NRC;
            if _Giro <> '' then
                gCustomer.Validate("DTE Activity Code", _Giro);

            gCustomer."FSN NRC Description" := CopyStr(gCustomer."DTE Active Description", 1, 100);
            gCustomer."FSN Foreign document" := _ExtrangeroNo_;
        END;

        if _Action = 1 then begin
            if Response_Text = '' then
                Response_Text := lText008;
            gCustomer.VALIDATE(gCustomer."No.", '');
            gCustomer."invoice Disc. Code" := gCustomer."No.";
            if not gCustomer.insert(true) then begin
                Response_Code := '3000';
                Response_Text := STRSUBSTNO(gText016, System.GetLastErrorText());
                EXIT('');
            END;

        END ELSE
            if not gCustomer.MODifY(TRUE) then begin
                Response_Code := '3003';
                Response_Text := STRSUBSTNO(gText015, System.GetLASTERRorTEXT);
                EXIT('');
            END;
        EXIT(gCustomer."No.");
    end;

    procedure CustomerValidateData
    (
        _Code: Code[20];
        DUI: Code[20];
        NIT: Text[20];
        NRC: Text[30];
        NoExtrangero: Code[20];
        Giro: Text[120];
        BirthDay: Date;
        ClientType: integer;
        IsNew: Boolean;
        var RestricOption_: Option Normal,NameOnly,ExcpName,All;
        var Response_Code: Text[10];
        var Response_Text: Text
    ) CustDataOk: Boolean
    var
        RegEx: DotNet Regex;
        Customer_l: Record Customer;
        FASANIServerUtil: Codeunit "FSN Utility";
        lText001: Label 'Cliente %1 tiene edicion restringida. %2';
        lText002: Label 'Solo nombre es editable';
        lText003: Label 'Nombre no es editable';
        lText004: Label 'Todo bloqueado';
    begin
        Customer_l.Get(_Code);
        Customer_l."FSN DUI" := DUI;
        Customer_l."VAT Registration No." := NIT;
        Customer_l."FSN NRC" := NRC;
        Customer_l."FSN NRC Description" := Giro;
        Customer_l."FSN Foreign document" := NoExtrangero;

        Customer_l."FSN Birthday" := BirthDay;
        if ClientType = 1 then
            Customer_l."FSN Customer Type" := Customer_l."FSN Customer Type"::Company
        ELSE
            Customer_l."FSN Customer Type" := Customer_l."FSN Customer Type"::Person;

        if not FASANIServerUtil.ValidateExtraCustomer('', FALSE, IsNew, Customer_l, Response_Text, RestricOption_) then begin
            CLEAR(Customer_l);
            Response_Code := '3333';
            EXIT(FALSE);
        END;

        CASE RestricOption_ OF
            RestricOption_::NameOnly:
                Response_Text := STRSUBSTNO(lText001, Customer_l."No.", lText002);
            RestricOption_::ExcpName:
                Response_Text := STRSUBSTNO(lText001, Customer_l."No.", lText003);
            RestricOption_::All:
                Response_Text := STRSUBSTNO(lText001, Customer_l."No.", lText004);
        END;

        CLEAR(Customer_l);

        EXIT(TRUE);
    end;

    procedure DeletePOSTransaction(ReceiptNo: Code[20])
    var
        POSinfocodeEntry_: Record "LSC POS Trans. infocode Entry";
    begin
        if POSTransactionTB.Get(ReceiptNo) then
            POSTransactionTB.DELETE(true);

        POSinfocodeEntry_.Reset();
        POSinfocodeEntry_.SetRange(POSinfocodeEntry_."Receipt No.", ReceiptNo);
        POSinfocodeEntry_.DeleteAll();
    end;

    /// <summary>
    /// Obtiene una lista de CLientes bajo un filtro
    /// </summary>
    /// <param name="Json">Objeto de filtro</param>
    /// <param name="res">arreglo de objetos de resultado</param>
    [ServiceEnabled]
    procedure GetCustomerList(Json: Text; var res: Text)
    var
        Cust: Record Customer;
        LSCMembershipCard: Record "LSC Membership Card";
        LSCMemberAcc: Record "LSC Member Account";
        FSNP: Record "FSN Parameter";
        JObject: JsonObject;
        _JObject: JsonObject;
        JArray: JsonArray;
        JToken: JsonToken;
        Value: Text;
        DefaultDate: DateTime;
        Top: Integer;
        Counter: Integer;
        DateFilt: text;
        DateValue: Date;
    begin
        Clear(Counter);
        res := '[]';
        JObject.ReadFrom(Json);
        Evaluate(DefaultDate, '1753-01-01 00:00:00');
        Top := 20;

        FSNP.Reset();
        FSNP.SetRange(Grupo, 'PREBILLER');
        FSNP.SetRange(Codigo, 'COUNTERTOP');
        if FSNP.FindFirst() and FSNP.Activo and (FSNP.Valor <> '') then
            if Evaluate(Top, FSNP.Valor) then;

        //* Filtro por VIP
        if JObject.SelectToken('VIP', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                if LSCMembershipCard.Get(JToken.AsValue().AsText()) then
                    if LSCMemberAcc.Get(LSCMembershipCard."Account No.") then
                        if Cust.Get(LSCMemberAcc."Linked To Customer No.") then begin
                            _JObject := GetCustomerByKey(Cust);
                            JArray.Add(_JObject);
                            JArray.WriteTo(res);
                            exit;
                        end;
                exit;
            end;
        end;

        //* Filtro por ID de Cliente
        if JObject.SelectToken('No_', JToken) and not (JToken.AsValue().IsNull) then
            if (JToken.AsValue().AsText() <> '') then begin
                if Cust.Get(JToken.AsValue().AsText()) then begin
                    _JObject := GetCustomerByKey(Cust);
                    JArray.Add(_JObject);
                    JArray.WriteTo(res);
                    exit;
                end else
                    exit;
            end;

        //* Filtros direfentes a No del Cliente
        if JObject.SelectToken('Name', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Value := Value.Trim();
                Value := ConvertStr(Value, ' ', '*');
                Cust.SetFilter(Name, '*' + Value + '*');
            end;
        end;
        if JObject.SelectToken('EMail', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Cust.SetFilter("E-Mail", '*' + Value + '*');
            end;
        end;
        if JObject.SelectToken('VATNo', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Cust.SetFilter("VAT Registration No.", '*' + Value + '*');
            end;
        end;

        if JObject.SelectToken('FechaNacimiento', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                if (JToken.AsValue().AsDateTime() > DefaultDate) then begin
                    DateFilt := (CopyStr(format(JToken.AsValue().AsText()), 1, 10));
                    if Evaluate(DateValue, DateFilt) then
                        Cust.SetFilter("FSN Birthday", '=%1', DateValue);
                end;
            end;
        end;

        if JObject.SelectToken('Gender', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsInteger() <> 0) then
                Cust.SetFilter("FSN Gender", '%1', JToken.AsValue().AsInteger());
        end;

        if JObject.SelectToken('PhoneNo_', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Cust.SetFilter("Phone No.", '*' + Value + '*');
            end;
        end;

        if JObject.SelectToken('TelexNo_', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Cust.SetFilter("Telex No.", '*' + Value + '*');
            end;
        end;

        if JObject.SelectToken('Address', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Cust.SetFilter("Address", '*' + Value + '*');
            end;
        end;

        if JObject.SelectToken('City', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Cust.SetFilter("City", '*' + Value + '*');
            end;
        end;

        if JObject.SelectToken('NRC', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Cust.SetFilter("FSN NRC", '*' + Value + '*');
            end;
        end;

        if JObject.SelectToken('GIRO', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                Value := JToken.AsValue().AsText();
                Cust.SetFilter("FSN NRC Description", '*' + Value + '*');
            end;
        end;

        if JObject.SelectToken('NDocumento', JToken) and not (JToken.AsValue().IsNull) then begin
            if (JToken.AsValue().AsText() <> '') then begin
                value := JToken.AsValue().AsText();
                Cust.SetFilter("FSN DUI", '*' + Value + '*');

                if not Cust.FindSet() then begin
                    Cust.SetRange("FSN DUI");
                    Cust.SetFilter("FSN Foreign document", Value);
                end;

                if not Cust.FindSet() then begin
                    Cust.SetRange("FSN Foreign document");
                    if Cust.GetFilters = '' then
                        exit;
                end;
            end;
        end else
            if Cust.GetFilters = '' then
                exit
            else
                if not Cust.FindSet() then
                    exit;

        repeat
            if Cust."No." <> '' then begin
                _JObject := GetCustomerByKey(Cust);
                JArray.Add(_JObject);
                Counter += 1;
            end;
        until (Cust.Next() = 0) or (Counter = Top);

        JArray.WriteTo(res);
    end;

    /// <summary>
    /// GetItemByKey.
    /// </summary>
    /// <param name="ItemNo">Code[20].</param>
    /// <param name="Response_Text">VAR Text.</param>
    /// <param name="Response_Code">VAR Text.</param>
    procedure GetItemByKey(ItemNo: Code[20]; var Response_Text: Text; var Response_Code: Text)
    var
        Item: Record Item;
        JObject: JsonObject;
    begin
        Response_Code := '0000';

        //? filtra el codigo de producto
        if not Item.Get(ItemNo) then begin
            Response_Code := '0001';
            Response_Text := 'Item not found';
            exit;
        end;

        JObject := GetItemByKey(Item);

        JObject.WriteTo(Response_Text);
    end;

    /// <summary>
    /// recibe algun parametro y si devuelve una lista de productos
    /// </summary>
    /// <param name="Json">json con los objetos de filtro</param>
    ///<param name="res">Texto de respuesta</param>
    /// <param name="Code">Codigo de respuesta</param>
    procedure GetItemList(Json: Text; var res: Text; var Code: Text)
    var
        Item: Record "Item";
        Barcode: Record "LSC Barcodes";
        ProductGroup: Record "LSC Retail Product Group";
        POSExchange: Record "FSN POS Exchange Setup";
        FSNPOSEIL: Record "FSN POS Exchange Item Link";
        _Jobject: JsonObject;
        JObject: JsonObject;
        JArray: JsonArray;
        JToken: JsonToken;
        DefaultDate: Date;
        Value: Text;
        ValueCount: Integer;
        p: File;
        o: OutStream;
        sb: DotNet StringBuilder;
    begin
        /*sb := sb.StringBuilder();
        sb.Append(Json);
        p.Create('C:\temp\GetItemList.txt');
        p.CreateOutStream(o);
        o.Write(sb.ToString());
        p.Close();*/
        //* iniciar las variables
        Code := '0000';
        Clear(res);
        res := '[]';
        Item.Reset();
        JObject.ReadFrom(Json);

        //? evalua si trae el id del producto
        /*if JObject.Get('No_', JToken) and (JToken.AsValue().AsText() <> '') then
            if Item.Get(JToken.AsValue().AsText()) then begin
                _Jobject := GetItemByKey(Item);
                JArray.Add(_Jobject.AsToken());
                JArray.WriteTo(res);
                exit;
            end else begin
                Code := '0001';
                exit;
            end;

        //? evalua si trae el codigo de barras
        if JObject.Get('Barcode', JToken) and (JToken.AsValue().AsText() <> '') then
            if Barcode.Get(JToken.AsValue().AsText()) then begin
                if Item.Get(Barcode."Item No.") then begin
                    _Jobject := GetItemByKey(Item);
                    JArray.Add(_Jobject.AsToken());
                    JArray.WriteTo(res);
                    exit;
                end;
            end else begin
                Code := '0001';
                exit;
            end;*/

        //? evalua si trae el id del producto
        if JObject.Get('No_', JToken) and (JToken.AsValue().AsText() <> '') then
            if Item.Get(JToken.AsValue().AsText()) then begin
                if Item."Item Category Code" = '05002' then begin//24102025
                    res := '[]';
                    Code := '0001';
                    exit;
                end;
                _Jobject := GetItemByKey(Item);
                JArray.Add(_Jobject.AsToken());
                JArray.WriteTo(res);
                exit;
            end else begin
                Code := '0001';
                exit;
            end;

        //? evalua si trae el codigo de barras
        if JObject.Get('Barcode', JToken) and (JToken.AsValue().AsText() <> '') then
            if Barcode.Get(JToken.AsValue().AsText()) then begin
                if Item.Get(Barcode."Item No.") then begin
                    if Item."Item Category Code" = '05002' then begin//24102025
                        res := '[]';
                        Code := '0001';
                        exit;
                    end;
                    _Jobject := GetItemByKey(Item);
                    JArray.Add(_Jobject.AsToken());
                    JArray.WriteTo(res);
                    exit;
                end;
            end else begin
                Code := '0001';
                exit;
            end;


        //* Evaluacion del resto de filtros
        if JObject.Get('Description', JToken) and (JToken.AsValue().AsText() <> '') then begin
            value := JToken.AsValue().AsText();
            Item.SetFilter(Description, '*' + Value + '*');
        end;
        if JObject.Get('Laboratory', JToken) and (JToken.AsValue().AsText() <> '') then begin
            Value := JToken.AsValue().AsText();
            Item.SetFilter("LSC Attrib 1 Code", '*' + Value + '*');
        end;
        if JObject.Get('Group', JToken) and (JToken.AsValue().AsText() <> '') then begin
            ProductGroup.Reset();
            ProductGroup.SetRange(Description, JToken.AsValue().AsText());
            if ProductGroup.FindFirst() then
                Item.SetRange("LSC Retail Product Code", ProductGroup.Code)
        end;
        if JObject.Get('Ingredients', JToken) and (JToken.AsValue().AsText() <> '') then begin
            Value := JToken.AsValue().AsText();
            Item.SetFilter("Description 2", '*' + Value + '*');
        end;
        if JObject.Get('Exchange', JToken) and (JToken.AsValue().AsText() <> '') then begin
            Value := JToken.AsValue().AsText();
            if Evaluate(DefaultDate, '17530101') then;
            POSExchange.Reset();
            POSExchange.SetFilter("POS Exchange Code", Value);
            POSExchange.SetFilter("Starting Date", '<= %1|%2', Today, DefaultDate);
            POSExchange.SetFilter("Ending Date", '>= %1|%2', Today, DefaultDate);
            if POSExchange.Find('-') then begin
                repeat
                    FSNPOSEIL.Reset();
                    FSNPOSEIL.SetRange("POS Exchange No.", POSExchange."No.");
                    if FSNPOSEIL.Find('-') then
                        repeat
                            Item.SetRange("No.", FSNPOSEIL."Item No.");
                            if Item.Find('-') then
                                repeat
                                    _Jobject := GetItemByKey(Item);
                                    JArray.Add(_Jobject.AsToken());
                                until Item.Next() = 0;
                        until FSNPOSEIL.Next() = 0;
                until POSExchange.Next() = 0;
                JArray.WriteTo(res);
                exit;
            end else begin
                Code := '0001';
                exit;
            end;
        end;
        if Item.GetFilters() = '' then
            exit;

        if Item.Find('-') then
            repeat
                _Jobject := GetItemByKey(Item);
                JArray.Add(_Jobject.AsToken());
            until Item.Next() = 0;
        JArray.WriteTo(res);
    end;

    /// <summary>
    /// carga todas las tarjetas asociadas a un cliente
    /// </summary>
    /// <param name="CustomerNo">Codigo del cliente</param>
    /// <param name="res"> arreglo de Json con todas las tarjetas</param>
    procedure GetMemberCardsByCust(CustomerNo: Code[20]; var res: Text)
    var
        MembershipCard: Record "LSC Membership Card";
        LSCMemberAcc: Record "LSC Member Account";
        JArray: JsonArray;
        Jobject: JsonObject;
        JToken: JsonToken;
    begin
        if CustomerNo = '' then
            exit;

        res := '[]';
        LSCMemberAcc.Reset();
        LSCMemberAcc.SetRange("Linked To Customer No.", CustomerNo);
        if not LSCMemberAcc.Find('-') then
            exit;

        repeat
            MembershipCard.Reset();
            MembershipCard.SetRange("Account No.", LSCMemberAcc."No.");
            if MembershipCard.Find('-') then
                repeat
                    Jobject := GetMemberCardByKey(MembershipCard);
                    JArray.Add(Jobject.AsToken());
                until MembershipCard.Next() = 0;
        until LSCMemberAcc.Next() = 0;

        JArray.WriteTo(res);
    end;

    procedure GetMemberinfo
    (
        DUI: Code[20];
        var MemberCard: Text[100];
        var LastMemberCard: Text[100];
        var LastValidDate: Text[20];
        CalculatePoints: Boolean;
        var Points: Decimal;
        var Response_Code: Text[10];
        var Response_Text: Text
    )
    var
        SqlConnection: DotNet SqlConnect;
        SqlCommand: DotNet SqlCmd;
        SqlDataReader: DotNet SqlDataRdr;
        Customer_l: Record Customer;
        MemberAccount_l: Record "LSC Member Account";
        MemberAccount2_l: Record "LSC Member Account";
        MembershipCard_l: Record "LSC Membership Card";
        MembershipCard2_l: Record "LSC Membership Card";
        Store_l: Record "LSC Store";
        RetailSeup_l: Record "LSC Retail Setup";
        PosFuncProfile: Record "LSC POS Func. Profile";
        POSFuncProfileWebServer: Record "LSC POS Func. Profile Web Serv";
        DisLocation: Record "LSC Distribution Location";
        POSFuncProfileWebReq: Record "LSC POS Func. Profile Web Req.";
        MemberAccountTemp: Record "LSC Member Account" temporary;
        WebServicesClient: Codeunit "LSC Web Services Client";
        POSTransactionServerUtil: Codeunit "LSC POS Trans. Server Utility";
        ConnectionString: Text[125];
        SqlString: Text;
        DUinEW: Text[30];
        AccountNo_: Code[20];
        ErrorNumber: integer;
        ForCount: integer;
        DocumentLinkExists: Boolean;
        ProcessError: Boolean;
        lTextConn: Label 'Data Source=%1;initial Catalog=%2;integrated Security=false; User ID=%3;Password=%4;';
        lText001: Label 'Tarjeta %1 no es valida (%2)';
        lText002: Label 'No Existe';
        lText003: Label 'Esta vencida. Expiró %1';
        lText004: Label 'DUI %1 No corresponde a la VIP %2';
        lText005: Label 'Debe definir DUI y Tarjeta VIP. Ambos valores no pueden estar vacios.';
        lTextSimbol: Label '''''';
    begin
        Response_Code := '0000';
        DocumentLinkExists := FALSE;
        Points := 0;
        Response_Text := '';
        LastValidDate := '';
        LastMemberCard := '';


        if (DUI = '') or (MemberCard = '') then begin
            Response_Code := '0040';
            Response_Text := lText005;
            EXIT;
        END;

        if MemberCard <> '' then
            if not MembershipCard_l.Get(MemberCard) then begin
                Response_Code := '0010';
                Response_Text := STRSUBSTNO(lText001, MemberCard, lText002);
                EXIT;
            END ELSE begin
                AccountNo_ := MembershipCard_l."Account No.";

                if AccountNo_ <> DUI then begin
                    if MemberAccount_l.Get(AccountNo_) then
                        if Customer_l.Get(MemberAccount_l."Linked To Customer No.") then begin
                            if (Customer_l."FSN DUI" = DUI) or (Customer_l."FSN Foreign document" = DUI) then
                                DocumentLinkExists := TRUE;

                            if not DocumentLinkExists then begin
                                DUinEW := DELCHR(DUI, '=', '-');
                                if (Customer_l."FSN DUI" = DUinEW) or (Customer_l."FSN Foreign document" = DUinEW) then
                                    DocumentLinkExists := TRUE;

                            END;
                        END;
                    if not DocumentLinkExists then begin
                        Response_Code := '0030';
                        Response_Text := STRSUBSTNO(lText004, DUI, MemberCard);
                        EXIT;
                    END;
                END;

                LastMemberCard := MembershipCard_l."Card No.";
                LastValidDate := Format(MembershipCard_l."Last Valid Date", 0, '<Day>/<Month Text>/<Year4>');
                if (MembershipCard_l."Last Valid Date" < TODAY) and (MembershipCard2_l.Status <> MembershipCard2_l.Status::Active) then begin
                    MembershipCard2_l.Reset();
                    MembershipCard2_l.SETCURRENTKEY("Account No.", "Last Valid Date");
                    MembershipCard2_l.SetRange(MembershipCard2_l."Account No.", MembershipCard_l."Account No.");
                    MembershipCard2_l.SETFILTER(MembershipCard2_l."Last Valid Date", '>=%1', TODAY);
                    MembershipCard2_l.SetRange(MembershipCard2_l.Status, MembershipCard2_l.Status::Active);
                    if not MembershipCard2_l.FinDLAST then begin
                        LastMemberCard := '';
                        Response_Code := '0020';
                        Response_Text := STRSUBSTNO(lText001, MemberCard, STRSUBSTNO(lText003, ForMAT(MembershipCard_l."Last Valid Date", 0, '<Day>/<Month Text>/<Year4>')));
                        EXIT;
                    END ELSE begin
                        LastMemberCard := MembershipCard2_l."Card No.";
                        LastValidDate := ForMAT(MembershipCard2_l."Last Valid Date", 0, '<Day>/<Month Text>/<Year4>');
                    END;
                END;
            END;

        if not CalculatePoints then
            EXIT;

        RetailSeup_l.Get;
        if not Store_l.Get(RetailSeup_l."Local Store No.") then EXIT;
        if not PosFuncProfile.Get(Store_l."Functionality Profile") then EXIT;

        if not POSFuncProfileWebReq.WebRequestActive(Store_l."Functionality Profile", 'FSN_GET_ACCOUNT_INFO') then EXIT;


        POSFuncProfileWebServer.Reset();
        POSFuncProfileWebServer.SETCURRENTKEY("Profile ID", "Request ID", Priority);
        POSFuncProfileWebServer.SetRange(POSFuncProfileWebServer."Profile ID", PosFuncProfile."Profile ID");
        POSFuncProfileWebServer.SetRange(POSFuncProfileWebServer."Request ID", 'FSN_GET_ACCOUNT_INFO');
        if not POSFuncProfileWebServer.FinDFIRST then EXIT;

        ForCount := 0;

        if not DisLocation.Get(POSFuncProfileWebServer."Dist. Location") then EXIT;

        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
        SqlConnection := SqlConnection.SqlConnection(ConnectionString);

        SqlString := 'SELECT ISNULL((' +
                      'SELECT ISNULL(SUM([SUM$Remaining Points]),0) FROM [dbo].[FASANI$Member Point Entry$VSifT$6] l ' +
                      'WHERE [Account No_]= ''' + AccountNo_ + ''' and [Open] = 1 and [Expiration Date] >= CONVERT(DATE,GetDATE())) + ' +
                      '(SELECT ISNULL(SUM([Points in Transaction]),0) FROM [FASANI$Member Process order Entry] ' +
                      'WHERE [Account No_]= ''' + AccountNo_ + ''' and [Date Processed] < ''01/01/1900''),0) Points';

        SqlConnection.Open();
        SqlCommand := SqlConnection.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        WHILE SqlDataReader.Read() and (ForCount < 1) DO begin
            Points := SqlDataReader.Item('Points');
            ForCount += 1;
        END;

        SqlDataReader.Close();
        SqlConnection.Close();

    end;

    procedure GetValidPriceGroup(CardNo: text) PriceGroup: Code[10]
    var
        MemberAccount: Record "LSC Member Account";
        MemberScheme: Record "LSC Member Scheme";
        MemberClub: Record "LSC Member Club";
        MemberCard: Record "LSC Membership Card";
        MemberCardMgt: Codeunit "LSC Member Card Management";
        MessaGetxt: text[250];
    begin
        if not MemberCardMgt.GetMembershipCard(CardNo, MemberCard, MessaGetxt) then
            EXIT('');

        if MemberAccount.Get(MemberCard."Account No.") then
            PriceGroup := MemberAccount."Price Group";

        if PriceGroup <> '' then
            EXIT;

        if MemberScheme.Get(MemberCard."Scheme Code") then
            PriceGroup := MemberScheme."Default Price Group";

        if PriceGroup <> '' then
            EXIT;

        if MemberClub.Get(MemberCard."Club Code") then
            PriceGroup := MemberClub."Default Price Group";

        EXIT;
    end;

    procedure InitLineFreeText(pFreeText: Text; pReceiptContext: Code[20])
    var
        NewLine: Record "LSC POS Trans. Line";
        POSTransaction_l: Record "LSC POS Transaction";
        LocalText: Text[100];
        LengthCounter: Integer;
        CurrentTransLine: Record "LSC POS Trans. Line";
        NextLine: Integer;
    begin
        IF (pFreeText = '') OR NOT POSTransaction_l.GET(pReceiptContext) THEN
            EXIT;

        LengthCounter := 1;
        CurrentTransLine.RESET;
        CurrentTransLine.SETCURRENTKEY("Receipt No.", "Line No.");
        CurrentTransLine.SETRANGE(CurrentTransLine."Receipt No.", POSTransaction_l."Receipt No.");
        IF CurrentTransLine.FINDLAST THEN
            NextLine := CurrentTransLine."Line No." + 10000;

        CLEAR(NewLine);
        NewLine."Store No." := POSTransaction_l."Store No.";
        NewLine."POS Terminal No." := POSTransaction_l."POS Terminal No.";
        NewLine."Receipt No." := POSTransaction_l."Receipt No.";
        NewLine."Guest/Seat No." := CurrentTransLine."Guest/Seat No.";
        NewLine."Restaurant Menu Type" := CurrentTransLine."Restaurant Menu Type";
        NewLine."Receipt No." := POSTransaction_l."Receipt No.";

        NewLine."Entry Type" := CurrentTransLine."Entry Type"::FreeText;
        NewLine."Text Type" := CurrentTransLine."Text Type"::"Freetext Input";

        WHILE STRLEN(pFreeText) + 75 > LengthCounter DO BEGIN
            LocalText := COPYSTR(pFreeText, LengthCounter, 75);
            LengthCounter += 75;

            IF LocalText <> '' THEN BEGIN
                NewLine.VALIDATE(NewLine.Description, LocalText);
                NewLine."Line No." := NextLine;
                NewLine.INSERT(TRUE);
                NextLine += 10000;
            END;
        END;
    end;

    procedure initReceiptModal(pReceipt: Code[20]; pSource: Code[20])
    begin
        ReceiptNo_g := pReceipt;
        gRequestFromID := pSource;
    end;

    procedure insertTransaction() NewReceiptNo: Code[20]
    var
        PosVisualProfile: Record "LSC POS Menu Profile";
        MemberContact_g: Record "LSC Member Contact" temporary;
        MemberAccount_g: Record "LSC Member Account" temporary;
        MemberClub_g: Record "LSC Member Club" temporary;
        PosFuncProfile: Record "LSC POS Func. Profile";
        NewLine: Record "LSC POS Trans. Line";
        LineRec: Record "LSC POS Trans. Line";
        SalesTypeRec: Record "LSC Sales Type";
        Customer: Record Customer;
        POSAction: Record "LSC POS Actions";
        PosTransation: Codeunit "LSC POS Transaction";
        PosFunc: Codeunit "LSC POS Functions";
        POSSESSION: Codeunit "LSC POS Session";
        HospFunc: Codeunit "LSC Hospitality Functions";
        POSGUI: Codeunit "LSC POS GUI";
        PosOfferExt: Codeunit "LSC POS Offer Ext. Utility";
        Description: Text;
        Description2: Text;
        Currinput: Text;
        CurrTableDescr: Text;
        LastSlipNum: Code[20];
        GLobalSalesType: Code[20];
        LineSalesType: Code[20];
        LinePriceGroup: Code[10];
        DealNo: Code[20];
        STATE: Code[10];
        STATE_SALES: Code[10];
        StateTxt: Code[30];
        CurrTableNo: integer;
        DealAddedPrice: Decimal;
        Remaining: Decimal;
        RemainingFCY: Decimal;
        TrainingActive: Boolean;
        OnlySelectCustomer: Boolean;
        SalesTypeFilter: Boolean;
        Text002: Label 'New transaction';
    begin
        if NewReceiptNo = '' then
            NewReceiptNo := insertTransSuspended(LastSlipNum, POSSESSION.WorkShiftNo, GLobalSalesType, CurrTableNo, TrainingActive, CurrTableDescr);  //LS7.1-05

        POSTransactionTB.Reset();
        POSTransactionTB.SetRange("Receipt No.", NewReceiptNo);

        POSTransactionTB.Get(NewReceiptNo);
        PosTransation.AfterGetRecord();

        if POSTransactionTB."Table No." <> 0 then
            PosFunc.insertTransinUseOnPos(POSTransactionTB."Receipt No.", POSSESSION.TerminalNo, TRUE, TRUE);

        Commit();
        POSTransactionTB.Get(NewReceiptNo);
        PosTransation.AfterGetRecord();
        HospFunc.insertOccupiedSeat(POSTransactionTB."Table No.", PosFuncProfile."Print Copy No. on Pre-Receipt", POSTransactionTB."Receipt No.", 0); //LS7.1-39

        //PosTransation.SetFunctionMode('ITEM');
        PosTransation.SetPOSState(STATE_SALES);
        StateTxt := '';
        if (Remaining = 0) and (RemainingFCY = 0) then begin
            Description := Text002;
            Description2 := '';
        end;
        PosTransation.SelectDefaultMenu;

        Commit();

        /*olopez if REC."Sales Type" <> '' then
             CheckSalesType(REC."Sales Type", 0); olopez*/
        LinePriceGroup := POSTransactionTB."Price Group Code";
        if SalesTypeFilter then begin
            LineSalesType := GLobalSalesType;
            if SalesTypeRec.Get(GLobalSalesType) then
                LinePriceGroup := SalesTypeRec."Price Group";
        end else begin
            if POSTransactionTB."original Sales Type" <> '' then
                LineSalesType := POSTransactionTB."original Sales Type"
            else
                LineSalesType := POSTransactionTB."Sales Type";
        end;

        DealNo := '';
        DealAddedPrice := 0;
    end;

    procedure insertTransSuspended
    (
        var LastSlipNumber: Code[20];
        ShiftNo: Code[1];
        SetSalesType: Code[20];
        TableNo: integer;
        TrainingActive: Boolean;
        TableDescr: Text
    ) NewSlipNo: Code[20]
    var
        TmpTrans: Record "LSC POS Transaction";
        SalesTypes: Record "LSC Sales Type";
        Storesetup: Record "LSC Store";
        PosFuncProfile: Record "LSC POS Func. Profile";
        PosTrGuestinfo1: Record "LSC POS Trans. Guest info";
        POSSESSION: Codeunit "LSC POS Session";
        posfunc: Codeunit "LSC POS Functions";
        Seq: integer;
        LoopCount: integer;
        insertOK: Boolean;
        SkipincrementSlipno: Boolean;
        Text260: Label 'ENU=Table %1;ESP=Mesa %1';
    begin
        if not POSTransactionTB.RecordLevelLocking then
            POSTransactionTB.LockTable(true, true);
        DeletePOSTransaction(ReceiptNo_g);
        POSTransactionTB."Receipt No." := PreBillerExt.GetLastReceiptNumber(POSSESSION.TerminalNo());
        POSTransactionTB."New Transaction" := false;
        POSTransactionTB."Transaction Type" := POSTransactionTB."Transaction Type"::Sales;
        POSTransactionTB."Store No." := POSSESSION.StoreNo;
        POSTransactionTB."POS Terminal No." := POSSESSION.TerminalNo;
        POSTransactionTB."Created on POS Terminal" := POSSESSION.TerminalNo;
        POSTransactionTB."Staff ID" := POSSESSION.StaffID;
        POSTransactionTB."Shift No." := ShiftNo;
        POSTransactionTB."VAT Bus.Posting Group" := Storesetup."Store VAT Bus. Post. Gr.";
        POSTransactionTB."Sale Is Return Sale" := false;
        POSTransactionTB."Sales Type" := SetSalesType;

        POSTransactionTB."Table No." := TableNo;
        if TableNo <> 0 then
            POSTransactionTB.Comment := StrSubstNo(Text260, Format(TableNo));
        POSTransactionTB."Dining Tbl. Description" := TableDescr;
        //POSTransactionTB."Entry Status" := POSTransactionTB."Entry Status"::Suspended;  //Cambio de " " a Suspended*
        if SetSalesType <> '' then
            if SalesTypes.Get(SetSalesType) then begin
                if SalesTypes."VAT Bus. Posting Group" <> '' then
                    POSTransactionTB.Validate("VAT Bus.Posting Group", SalesTypes."VAT Bus. Posting Group");
                if SalesTypes."Price Group" <> '' then
                    POSTransactionTB.Validate(POSTransactionTB."Price Group Code", SalesTypes."Price Group");
            end;

        POSTransactionTB."Hosp. Type Sequence" := 0;
        if Evaluate(Seq, POSSESSION.GetValue('HOSTYPSEQ')) then
            POSTransactionTB."Hosp. Type Sequence" := Seq;

        LoopCount := 0;
        insertOK := false;

        if not POSTransactionTB.Insert() then begin
            while (not insertOK) and (LoopCount < 2) do begin
                LoopCount += 1;
                Sleep(100);

                if POSTransactionTB.Insert() then
                    insertOK := true;
            end;
        end else
            insertOK := true;

        Commit();
        if (TableNo > 0) or PosFuncProfile."Print Copy No. on Pre-Receipt" then begin
            Clear(PosTrGuestinfo1);
            if PosTrGuestinfo1.Get(POSTransactionTB."Receipt No.", 0) then begin
                PosTrGuestinfo1."Table No." := TableNo;
                PosTrGuestinfo1.Modify();
            end else begin
                PosTrGuestinfo1.Init();
                PosTrGuestinfo1."Receipt No." := POSTransactionTB."Receipt No.";
                PosTrGuestinfo1."Table No." := TableNo;
                PosTrGuestinfo1.Insert(true);
            end;
        end;

        Commit();
        exit(POSTransactionTB."Receipt No.");
    end;

    procedure IsCouponValid
    (
        VAR Response_Text: Text[250];
        VAR Response_Code: Text[20];
        VAR CouponCodeNext: Code[20];
        BarcodeNo: Code[22];
        MemberCardNo: Text[100];
        StoreNo: Code[10];
        TenderType: Code[10];
        Bin: Code[10]
    ) IsValid: Boolean;
    VAR
        CouponEntry: Record 99001643;
        CouponEntry2: Record 99001643;
        MembershipCard: Record 99009003;
        TransCouponEntry: Record 99001477;
        POSTransaction: Record 99008980;
        POSTransLine: Record 99008981;
        CouponHeader: Record 99001621;
        LastPOSTransLine: Record 99008981;
        CouponEntryin: Record 99001643;
        Store_l: Record 99001470;
        BinList_l: Record 50008;
        FasaniOfferExt: Record 50063;
        Item: Record 27;
        MemberCardManagement: Codeunit 99009001;
        RetailPriceUtils: Codeunit 99001462;
        BOUtils: Codeunit 99001452;
        MessaGetxt: Text[250];
        lText001: Label 'ENU=El No. de cupon esta vac¡o';
        lText002: Label 'ENU=El No. de cupon %1 %2';
        lText003: Label 'ENU=No es valido';
        lText004: Label 'ENU=No esta vigente';
        lText005: Label 'ENU=No es valido para %1';
    begin
        //IsCouponValid from codeunit CouponManagement
        BarcodeNo := UPPERCASE(BarcodeNo);
        Response_Text := '0000';
        CLEAR(Response_Code);
        CLEAR(CouponHeader);

        if BarcodeNo = '' then begin
            Response_Text := lText001;
            Response_Code := '0001';
            EXIT(FALSE);
        END;
        if not CouponHeader.Get(BarcodeNo) then begin
            Response_Text := STRSUBSTNO(lText002, BarcodeNo, lText003);
            Response_Code := '0002';
            EXIT(FALSE);
        END;

        MessaGetxt := '';
        /*
            ReturnCouponHeader(BarcodeNo, LastPOSTransLine."POS Terminal No.", CouponHeader, CouponEntry, MessaGetxt);
            No se crearan
            if (MessaGetxt = '') and
          (CouponHeader."Coupon ID Method" = CouponHeader."Coupon ID Method"::"Serial No.") and
          (BarcodeNo <> '') then begin
              POSTransLine.Reset();
              POSTransLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
              POSTransLine.SetRange("Receipt No.", LastPOSTransLine."Receipt No.");
              POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::Coupon);
              POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
              POSTransLine.SetRange("Coupon Barcode No.", BarcodeNo);
              if POSTransLine.FinDFIRST then
                  MessaGetxt := STRSUBSTNO(Text049, CouponHeader.Code, CouponHeader.Description, BarcodeNo);
          END;
          if MessaGetxt <> '' then begin
              ErrorMsg := MessaGetxt;
              EXIT(FALSE);
          END;
        *///not create new Coupon

        //CouponEntryin := CouponEntry;

        //if CouponHeader.Code = '' then
        //EXIT(FALSE);

        /*
            if not POSTransaction.Get(POSTransactionCodeunit.GetReceiptNo) then
            if CouponHeader.Affects = CouponHeader.Affects::"Last Item Line" then begin
                ErrorMsg := Text041;
                EXIT(FALSE);
            END;
        */// no transaction

        if CouponHeader.Status = CouponHeader.Status::Disabled then begin
            Response_Text := STRSUBSTNO(lText002, BarcodeNo, lText004);
            Response_Code := '0003';
            EXIT(FALSE);
        END;

        if not RetailPriceUtils.DiscValPerValid(CouponHeader."Validation Period ID", TODAY, TIME) then begin
            Response_Text := STRSUBSTNO(lText002, BarcodeNo, lText004);
            Response_Code := '0004';
            EXIT(FALSE);
        END;


        if CouponHeader."Price Group" <> '' then
            if not BOUtils.PriceGroupValidinStore2(CouponHeader."Price Group", StoreNo) then begin
                CLEAR(Store_l);
                if not Store_l.Get(StoreNo) then begin
                    Store_l.inIT;
                    Store_l.Name := StoreNo;
                END;
                Response_Text := STRSUBSTNO(lText002, BarcodeNo, STRSUBSTNO(lText005, Store_l.Name));
                Response_Code := '0005';
                EXIT(FALSE);
            END;

        if (CouponEntry."First Valid Date" > 0D) and (CouponEntry."First Valid Date" > WorKDATE) then begin
            Response_Text := STRSUBSTNO(lText002, BarcodeNo, lText004);
            Response_Code := '0006';
            EXIT(FALSE);
        END;

        if (CouponEntry."Last Valid Date" > 0D) and (CouponEntry."Last Valid Date" < WorKDATE) then begin
            Response_Text := STRSUBSTNO(lText002, BarcodeNo, lText004);
            Response_Code := '0007';
            EXIT(FALSE);
        END;

        if (CouponHeader."Entry Validation" = CouponHeader."Entry Validation"::"Apply to Entry") or
          //not tender-
          (CouponHeader.Handling = CouponHeader.Handling::Tender) or
          //not tender+
          (CouponHeader."Coupon ID Method" = CouponHeader."Coupon ID Method"::"Serial No.") then begin

            /*if BarcodeNo = CouponHeader.Code then begin
              Response_Text := STRSUBSTNO(Text044,BarcodeNo,CouponHeader.Description);
              Response_Code := '0008';
              EXIT(FALSE);
            END;
            CouponEntry2.Reset();
            CouponEntry2.SETCURRENTKEY("Coupon Code",Barcode,Status);
            CouponEntry2.SetRange("Coupon Code",CouponHeader.Code);
            CouponEntry2.SetRange(Barcode,BarcodeNo);
            CouponEntry2.SetRange(Status,CouponEntry2.Status::Open);
            CouponEntry2.SetRange("Coupon Function",CouponEntry2."Coupon Function"::Issue);
            if not CouponEntry2.FinDFIRST then begin
              ErrorMsg := STRSUBSTNO(Text045,CouponHeader.Code,CouponHeader.Description,
                CouponHeader.FIELDCAPTION("Entry Validation"),CouponHeader."Entry Validation",BarcodeNo);
              EXIT(FALSE);
            END;
            */

            Response_Text := 'No valido para ecommerce';
            Response_Code := '0009';
            EXIT(FALSE);
        END;

        if (CouponHeader."Entry Validation" = CouponHeader."Entry Validation"::"not Found & Create") then begin
            /*
            if BarcodeNo = CouponHeader.Code then begin
              ErrorMsg := STRSUBSTNO(Text044,BarcodeNo,CouponHeader.Description);
              EXIT(FALSE);
            END;
            CouponEntry2.Reset();
            CouponEntry2.SETCURRENTKEY("Coupon Code",Barcode,Status);
            CouponEntry2.SetRange("Coupon Code",CouponHeader.Code);
            CouponEntry2.SetRange(Barcode,BarcodeNo);
            if CouponEntry2.FinDFIRST then begin
              ErrorMsg := STRSUBSTNO(Text045,CouponHeader.Code,CouponHeader.Description,
                CouponHeader.FIELDCAPTION("Entry Validation"),CouponHeader."Entry Validation",BarcodeNo);
              EXIT(FALSE);
            END;
            */
            Response_Text := 'No valido para ecommerce';
            Response_Code := '0010';
            EXIT(FALSE);

        END;

        if CouponHeader."Member Value" <> '' then begin
            if MemberCardNo = '' then begin
                /*ErrorMsg := STRSUBSTNO(Text039, BarcodeNo, CouponHeader.Description, CouponHeader."Member Type",
                  CouponHeader."Member Value");*/
                Response_Text := 'Solo aplica para membresia';
                Response_Code := '0011';
                EXIT(FALSE);
            END;
            CLEAR(MembershipCard);
            MemberCardManagement.GetMembershipCard(MemberCardNo, MembershipCard, MessaGetxt);
            if MembershipCard."Account No." = '' then begin
                /*ErrorMsg := STRSUBSTNO(Text039,BarcodeNo,CouponHeader.Description,CouponHeader."Member Type",
                   CouponHeader."Member Value");*/
                Response_Text := 'Tarjeta no valida';
                Response_Code := '0012';
                EXIT(FALSE);
            END;
            if ((CouponHeader."Member Type" = CouponHeader."Member Type"::Scheme) and
                (MembershipCard."Scheme Code" <> CouponHeader."Member Value")) or
               ((CouponHeader."Member Type" = CouponHeader."Member Type"::Club) and
                (MembershipCard."Club Code" <> CouponHeader."Member Value")) then begin

                /*ErrorMsg := STRSUBSTNO(Text039, BarcodeNo, CouponHeader.Description, CouponHeader."Member Type",
                  CouponHeader."Member Value");*/
                Response_Text := 'Tarjeta no valida';
                Response_Code := '0013';
                EXIT(FALSE);
            END;
        END;

        if CouponHeader."Max per Member" > 0 then begin
            if MemberCardNo = '' then begin
                //ErrorMsg := STRSUBSTNO(Text035,BarcodeNo,CouponHeader.Description);
                Response_Text := 'Solo aplica para tarjeta vip';
                Response_Code := '0014';
                EXIT(FALSE);
            END;

            CLEAR(MembershipCard);
            MemberCardManagement.GetMembershipCard(MemberCardNo, MembershipCard, MessaGetxt);
            if MembershipCard."Account No." = '' then begin
                //ErrorMsg := STRSUBSTNO(Text036,MemberCardNo,BarcodeNo,CouponHeader.Description);
                Response_Text := 'Tarjeta membresia no valida';
                Response_Code := '0015';
                EXIT(FALSE);
            END;

            TransCouponEntry.Reset();
            TransCouponEntry.SETCURRENTKEY("Coupon Code", "Member Account No.", "Coupon Function");
            TransCouponEntry.SetRange("Coupon Code", CouponHeader.Code);
            TransCouponEntry.SetRange("Member Account No.", MembershipCard."Account No.");
            TransCouponEntry.SetRange("Coupon Function", TransCouponEntry."Coupon Function"::Use);
            TransCouponEntry.CALCSUMS("Used Quantity");
            if TransCouponEntry."Used Quantity" >= CouponHeader."Max per Member" then begin
                Response_Text := 'Llego al limite de usos';
                Response_Code := '0016';
                EXIT(FALSE);
            END;
        END;
        /*
        if CouponHeader.Affects = CouponHeader.Affects::"Last Item Line" then begin
              if not Item.Get(LastPOSTransLine.Number) then
                  CLEAR(Item);
              if (LastPOSTransLine."Entry Type" <> LastPOSTransLine."Entry Type"::Item) or
                (LastPOSTransLine.Number = '') then begin
                  ErrorMsg := Text038;
                  EXIT(FALSE);
              END;
              if not IsCouponValidForItemLine(CouponHeader, LastPOSTransLine) then begin
                  ErrorMsg := Text038;
                  EXIT(FALSE);
              END;
              ErrorMsg := '';
              EXIT(TRUE);
          END;

          if CouponHeader.Affects = CouponHeader.Affects::"Next Item Line" then begin
              if CouponCodeNextItem = '' then begin
                  ErrorMsg := '';
                  CouponCodeNextItem := BarcodeNo;
                  EXIT(FALSE);
              END
              ELSE begin
                  CouponCodeNextItem := '';
                  EXIT(TRUE);
              END;
          END;
        */
        EXIT(TRUE);
    END;

    procedure LoginManager
    (
        _StaffID: Code[20];
        _StoreNo_: Code[10];
        _TerminalNo_: Code[10];
        Password: Text[20];
        var Response_Code: Text[10];
        var Response_Text: Text
    ) LoginOK: Boolean
    var
        StaffRecord: Record "LSC Staff";
        TerminalRecord: Record "LSC POS Terminal";
        StoreRecord: Record "LSC Store";
        POSCommandCU: Codeunit "LSC Additional POS Commands";
        lText001: Label 'Nada que hacer. Error no identificado';
        lText002: Label 'El codigo de empleado %1 No existe';
        lText003: Label 'Contraseña no es valida';
        lText004: Label 'El empleado ID %1 no tiene permisos de Manager';
        lText005: Label 'El registro %1 no existe en la base de datos %2';
        PERMISIONMANAGER: Label 'MANAGER';
    begin
        Response_Code := '0000';
        Response_Text := lText001;

        if not StaffRecord.Get(_StaffID) then begin
            Response_Code := '4001';
            Response_Text := STRSUBSTNO(lText002, _StaffID);
            EXIT(FALSE);
        END ELSE
            if StaffRecord."Permission Group" <> PERMISIONMANAGER then begin
                Response_Code := '4004';
                Response_Text := STRSUBSTNO(lText004, _StaffID);
                EXIT(FALSE);
            END;

        if not TerminalRecord.Get(_TerminalNo_) then begin
            Response_Code := '4002';
            Response_Text := STRSUBSTNO(lText005, _TerminalNo_, TerminalRecord.TABLECAPTION);
            EXIT(FALSE);
        END;
        if not StoreRecord.Get(_StoreNo_) then begin
            Response_Code := '4003';
            Response_Text := STRSUBSTNO(lText005, _StoreNo_, StoreRecord.TABLECAPTION);
            EXIT(FALSE);
        END;

        POSSession.init;
        POSSession.SetStaff(_StaffID);
        //POSSession.SetTempStoreTerminal(_StoreNo_, _TerminalNo_, 'POS'); //olopez

        if StaffRecord.IsPassWordValid(Password) then begin
            Response_Text := '';
            EXIT(TRUE);
        END ELSE begin
            Response_Code := '4005';
            Response_Text := lText003;
            EXIT(FALSE);
        END;

        EXIT(FALSE);
    end;

    procedure MemberCardReplace(var XMLRequest: Text; var XMLResponse: Text; var RequestID: Text[50])
    var
        ReplaceMemberCard: Codeunit "FSN integration Member";
    begin
        ReplaceMemberCard.SetRequest(XMLRequest, RequestID);
        ReplaceMemberCard.Run();
        ReplaceMemberCard.GetResponse(XMLResponse, RequestID);
    end;

    procedure MemberManagement
    (
        pMemberCard: Text[100];
        pClubCode: Code[10];
        pSchemeCode: Code[10];
        pCustomerNo: Code[20];
        pPOSTerminalNo: Code[10];
        pIDAccountSuggest: Code[20];
        pBeneficiario: Text[100];
        pAction: integer;
        pStaff: Code[20];
        var Response_Code: Text[10];
        var Response_Text: Text
    ): Boolean
    var
        POSTerminal_l: Record "LSC POS Terminal";
        integrationMember: Codeunit "FSN integration Member";
        StoreCode_l: Code[10];
        lText001: Label 'Nada que hacer, acción ID = %1';
        lText002: Label 'El club %1 no existe';
        lText003: Label 'La tarjeta %1 aun esta vigente, vence el %2';
        lText004: Label 'El cliente debe ser mayor de Edad.';
        lText005: Label 'Cliente no existe %1';
        lText006: Label 'Fecha nacimiento no es correcta';
        lText007: Label 'El documento legal de cliente no puede esta vario.';
        lText008: Label 'No se puede Afiliar / Renovar a un cliente COMODin';
    begin
        Commit();
        //Action 1 = Crear, 2 = Renovar
        Response_Code := '0000';
        Response_Text := '';//STRSUBSTNO(lText001, ForMAT(pAction));
        if not (pAction in [1, 2]) then begin
            Response_Code := '0100';
            exit(false);
        end;

        Clear(POSTerminal_l);
        if POSTerminal_l.Get(pPOSTerminalNo) then
            StoreCode_l := POSTerminal_l."Store No.";

        if pIDAccountSuggest = '' then begin
            Response_Code := '0195';
            Response_Text := lText007;
            exit(false);
        end;

        if not gCustomer.Get(pCustomerNo) then begin
            Response_Code := '0192';
            Response_Text := lText005;
            exit(false);
        end;

        if (gCustomer."FSN DUI" <> '') or (gCustomer."FSN Foreign document" <> '') then begin
            if gCustomer."FSN Birthday" = 0D then begin
                Response_Code := '0194';
                Response_Text := lText006;
                exit(false);
            end;

            if CALCDATE('<+18Y>', gCustomer."FSN Birthday") > TODAY then begin
                Response_Code := '0191';
                Response_Text := lText004;
                exit(false);
            end;
        end;

        if gCustomer."LSC Retail Customer Group" = _COMODIN then begin
            Response_Code := '0196';
            Response_Text := lText008;
            exit(false);
        end;

        if pBeneficiario = '' then begin
            Response_Code := '0190';
            Response_Text := gText010;
            exit(false);
        end;

        if pAction = 2 then begin
            if not gMemberCard.Get(pMemberCard) then begin
                Response_Code := '0200';
                Response_Text := StrSubstNo(gText001, pMemberCard, gMemberCard.TABLECAPTION);
                exit(false);
            end;
        end else begin
            if gMemberCard.Get(pMemberCard) then begin
                Response_Code := '0205';
                Response_Text := StrSubstNo(gText009, pMemberCard);
                exit(false);
            end;
        end;

        if not gMemberClub.Get(pClubCode) then begin
            Response_Code := '0210';
            Response_Text := StrSubstNo(gText001, pClubCode, gMemberClub.TABLECAPTION);
            exit(false);
        end else
            if Format(gMemberClub."Card Expiration") = ' ' then begin
                Response_Code := '0215';
                Response_Text := StrSubstNo(gText011, pClubCode);
                exit(false);
            end;

        if not gMemberScheme.Get(pSchemeCode) then begin
            Response_Code := '0220';
            Response_Text := StrSubstNo(gText001, pSchemeCode, gMemberScheme.TABLECAPTION);
            exit(false);
        end;

        if not integrationMember.MemberMgtCard(pAction, pMemberCard, pClubCode, pSchemeCode, pCustomerNo, StoreCode_l, pIDAccountSuggest, pBeneficiario, pStaff, gCustomer."Customer Disc. Group", gCustomer.Name, gCustomer."Customer Price Group", gMemberClub."Card Expiration", Response_Text) then begin
            Response_Text := StrSubstNo(gText013, pMemberCard, pClubCode, pSchemeCode);
            exit(false);
        end;

        exit(true);
    end;

    procedure RecalcEcommerOfferPrice2()
    var
        Staff_l: Record "LSC Staff";
        POSTerminal_l: Record "LSC POS Terminal";
        Store_l: Record "LSC Store";
        Item_l: Record Item;
        ItemUM_l: Record "Unit of Measure";
        POSTransPerDisc: Record "LSC POS Trans. Per. Disc. Type";// "LSC POS Trans. Periodic Disc.";
        POSTransPerDisc2: Record "LSC POS Trans. Per. Disc. Type"; //"LSC POS Trans. Periodic Disc.";
        OfferPosCalc2: Record "LSC Offer Pos Calculation";
        OfferPosCalc: Record "LSC Offer Pos Calculation";
        POSTransLineTEMP_l: Record "LSC POS Trans. Line" temporary;
        PeriodicDiscountTender: Record "LSC Periodic Discount";
        PeriodicDiscLine: Record "LSC Periodic Discount Line";
        SalesType: Record "LSC Sales Type";
        POSTransLine2: Record "LSC POS Trans. Line";
        PosPrice: Codeunit "LSC POS Price Utility";
        PosPriceUtil: Codeunit "LSC POS Price Utility";
        Exec: Codeunit "FSN WS Prefacturador";
        Receipt_Local: Code[20];
        i: integer;
        NumerOfRows: integer;
        x: integer;
        initDiscountRecord: Decimal;
        OffDisc: Decimal;
    begin

        if Exec.RUN then;
        EXIT;
    end;

    procedure RecalcProcess()
    var
        POSTransPerDisc: Record "LSC POS Trans. Per. Disc. Type";
        POSTransLine2: Record "LSC POS Trans. Line";
        OfferPOSCalc: Record "LSC Offer Pos Calculation";
        PosPriceUtil: Codeunit "LSC POS Price Utility";
        DT: Record "LSC POS Trans. Per. Disc. Type";
        POSPrepaymentUtil: Codeunit "LSC POS Prepayment Mgt.";
        lPrice: Decimal;
        lQty: Decimal;
        PromOnCustDiscGroup: Boolean;
    begin
        //aplicar el cambio de precio
        PreBillerExt.ProcessCustomer(POSTransactionTB);
        POSTransactionTB.Get(POSTransactionTB."Receipt No.");
        POSTransPerDisc.Reset();
        POSTransPerDisc.SetCurrentKey(DiscType);
        POSTransPerDisc.SetRange(DiscType, POSTransPerDisc.DiscType::Customer);
        POSTransPerDisc.SetRange("Receipt No.", POSTransactionTB."Receipt No.");
        if POSTransPerDisc.Find('-') then begin
            repeat
                POSTransLine2.Get(POSTransPerDisc."Receipt No.", POSTransPerDisc."Line No.");
                PosPriceUtil.InsertTransDiscPercent(POSTransLine2, 0, POSTransPerDisc.DiscType::Customer.Asinteger(), '');
                POSTransLine2.CalcPrices;
                if not PosFuncProfile."Disable POS Prepayment" then
                    POSPrepaymentUtil.SetPosTransLinePrepaymentPct(POSTransLine2);
                POSTransLine2.Modify(true);
            until POSTransPerDisc.Next = 0;
        end;

        PosFunc.ChangeVATBusOnLine(POSTransactionTB);
        PromOnCustDiscGroup := PosPriceUtil.IsPromotionForCustDiscGroup(POSTransactionTB."Customer Disc. Group", POSTransactionTB);
        POSTransLine2.Reset();
        POSTransLine2.SetRange("Receipt No.", POSTransactionTB."Receipt No.");
        POSTransLine2.SetRange("Entry Type", POSTransLine2."Entry Type"::Item);
        if POSTransLine2.FinD('-') then
            repeat
                Clear(OfferPOSCalc);
                OfferPOSCalc.SetRange("Receipt No.", POSTransLine2."Receipt No.");
                OfferPOSCalc.SetRange("Trans. Line No.", POSTransLine2."Line No.");
                OfferPOSCalc.DeleteAll();
                PosPriceUtil.insertTransDiscPercent(POSTransLine2, 0, POSTransPerDisc.DiscType::"Periodic Disc.".Asinteger(), '');
                if PromOnCustDiscGroup then begin
                    lPrice := POSTransLine2.Price;
                    lQty := POSTransLine2.Quantity;
                    PosPriceUtil.insertTransDiscPercent(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".Asinteger(), '');
                    POSTransLine2."Promotion No." := '';
                    POSTransLine2."Mix & Match Line No." := 0;
                    PosPriceUtil.insertTransDiscAmount(POSTransLine2, 0, DT.DiscType::"Periodic Disc.".Asinteger(), '');
                    if not POSTransLine2."Price Change" then
                        PosPriceUtil.CalcPrice(POSTransLine2, FALSE);
                    if (lPrice <> POSTransLine2.Price) then begin
                        POSTransLine2.Validate(Quantity, lQty);
                        POSTransLine2.Modify(true);
                    end;
                end;
                PosPriceUtil.initGlobals(POSTransLine2, TRUE);
                PosPriceUtil.FindPeriodicOffers(POSTransLine2);
                POSTransLine2.Modify(true);
            until POSTransLine2.NEXT = 0;

        PosPriceUtil.CalcPeriodicOnTotalPressed(POSTransactionTB);
        PosFunc.RecalcSlip(POSTransactionTB);
    end;

    procedure RunProcess
    (
        var Arr_Item: array[50] of Code[20];
        var Arr_Description: array[50] of Code[100];
        var Arr_Unit_Of_Measure: array[50] of Code[20];
        var Arr_Qty: array[50] of integer;
        var Arr_EntryType: array[50] of integer;
        Store: Code[10];
        Terminal: Code[10];
        SalesStaff: Code[20];
        ManagerKey: Code[20];
        Customer: Code[20];
        MemberCard: Code[20];
        SchemeCode: Code[20];
        MemberPoints: Decimal;
        RequestFromID: Code[20];
        var Arr_UnitPriceincVAT: array[50] of Decimal;
        var Arr_Discount: array[50] of Decimal;
        var Arr_Amount: array[50] of Decimal;
        var Arr_EffDisc: array[50] of Decimal;
        var Arr_EffAmt: array[50] of Decimal;
        var TotalAmount: Decimal;
        var TotalDiscount: Decimal;
        var Balance: Decimal;
        var BalanceVIP: Decimal;
        var Response_Code: Text[10];
        var Response_Text: Text;
        OnlyCalculate: Boolean
    ) TransReceipt: Code[20];
    var
        Filestring: Text;
        FileSystem: DotNet StreamWriter;
        RecRef: RecordRef;
        OfferTable: Record "LSC Offer";
        POSTransaction_l: Record "LSC POS Transaction";
        SchemeTemp: Record "LSC Member Scheme";
        ExchanGetransLine_l: Record "FSN POS Exchange Transaction";
        MemberAcc2: Record "LSC Member Account";
        POSMenuLine: Record "LSC POS Menu Line";
        TableRequestWS: Record "LSC WS Request";
        TableRequestStatus: Record "FSN WebServiceTable";
        POSTransLineTEMP_l: Record "LSC POS Trans. Line" temporary;
        //TableRequestStatusTmp: Record "FSN WebServiceTable" temporary;
        POSTransactionTMP: Record "LSC POS Transaction" temporary;
        PosTransaction4: Record "LSC POS Transaction";
        Deliveryorder4: Record "LSC Delivery order";
        Pago_l: Record "LSC POS Trans. Line";
        StoreExtra: Record "LSC Store";
        TenderTypeS_l: Record "LSC Tender Type";
        Bincoupon: Record "FSN Bin Bank";
        Customer2: Record Customer;
        Customer1: Record Customer;
        customer_temp: Record Customer;
        CSWEB: Record "FSN WebServiceTable";
        Couponheader_l: Record "LSC Coupon Header";
        OdataCNN: Codeunit "OData Action Management";
        PosPrice: Codeunit "LSC POS Price Utility";
        TrasLineEntryEnum: Enum "LSC POS Trans. Line Entry Type";
        OfferType: Option "Periodic Disc.",Customer,infoCode,Total,Line,Promotion,Deal,"Total Discount","Tender Type","Item Point","Line Discount";
        TransactorText: Text;
        Tcommand: Text[50];
        Tresponse: Text;
        CustDiscGroupTemp: Code[20];
        TransCustomerDiscGroup: Code[10];
        Custom2Code: Code[20];
        i, paymentPosition : integer;
        Line: integer;
        LineExchange: integer;
        Enuminteger: integer;
        TotalLines: integer;
        Processed: Boolean;
        couponChangeOffer: Boolean;
        ArrSpecialAction: ARRAY[3] OF Boolean;
        lText001: Label 'ENU=Nada que hacer';
        lText002: Label 'ENU=Item %1, Descript %2, Price %3, Disc. %4, Qty %5';
        lText003: Label 'ENU=Cuando el esquema (%1) es definido para calculos no debe definir tarjeta.';
        lText004: Label 'ENU=El esquema membresia %1 no existe';
        lText005: Label 'ENU=Cliente es obligatorio';
        lText006: Label 'ENU=No se pudo enviar prefactura al destinatario.';
        lText007: Label 'ENU=No se pudo crear un pago para DELIVERY, intente de nuevo';
        lText008: Label 'ENU=Error de prefactura RequestFromID: %1, JSON: %2\Llame a soporte';
        lText009: Label 'ENU=Cupon BAC. AMERICA CENTRAL: No debe mezclar cobro TARJETA/RENOVACION VIP con otro producto';
        ErrorOninvokeGlobalChannelEvent: Label 'ErrorOninvokeGlobalChannelEvent %1';
        p: File;
        o: OutStream;
        sb: DotNet StringBuilder;
        Parameter: Record "FSN Parameter";
        POSTransLinbe: Record "LSC POS Trans. Line";
    begin

        GLOBALPROCESLOT := Response_Text;

        /*sb := sb.StringBuilder();
        sb.Append(GLOBALPROCESLOT);
        p.Create('C:\temp\GLOBALPROCESLOT.txt');
        p.CreateOutStream(o);
        o.Write(sb.ToString());
        p.Close();*/

        SelectLatestVersion();
        Clear(ReceiptNo_g);
        gIsMarkLines := false;

        if RequestFromID = 'DRIVETHRU' then begin
            gIsMarkLines := true;
            RequestFromID := 'POS';
        end;


        Parameter.Reset();
        Parameter.SetRange(Grupo, 'ONCAL');
        Parameter.SetRange(Codigo, 'PREF');
        IF (Parameter.FindFirst()) AND (Parameter.Activo) then
            if OnlyCalculate then begin
                preBillerExt.CalculationProcess(
                    Arr_Item,
                    Arr_Description,
                    Arr_Unit_Of_Measure,
                    Arr_Qty,
                    Arr_EntryType,
                    Arr_UnitPriceincVAT,
                    Arr_Discount,
                    Arr_Amount,
                    Arr_EffDisc,
                    Arr_EffAmt,
                    TotalDiscount,
                    TotalAmount,
                    Balance,
                    BalanceVIP,
                    Customer,
                    MemberCard,
                    Response_Text
                );
                Response_Code := '0000';
                exit;
            end;

        TransactorText := Response_Text;
        gRequestFromID := RequestFromID;

        GetMemberinfoExt(MemberCard);

        Response_Code := '0000';
        Response_Text := lText001;

        PreBillerExt.GlobalSusped(OnlyCalculate);

        GLOBALLANGUAGE(2058);

        if OnlyCalculate and (SchemeCode <> '') and (MemberCard <> '') then begin
            Response_Code := '0001';
            Response_Text := StrSubstNo(lText003, SchemeCode);
            exit('');
        end;

        CustDiscGroupTemp := '';
        if (SchemeCode <> '') and OnlyCalculate then begin
            if not SchemeTemp.Get(SchemeCode) then begin
                Response_Code := '0002';
                Response_Text := StrSubstNo(lText004, SchemeCode);
                exit('');
            end;
            if SchemeTemp."Default Cust. Disc. Group" <> '' then
                CustDiscGroupTemp := SchemeTemp."Default Cust. Disc. Group";
        end;

        //ECOMMERCE-
        if not (gRequestFromID in ['DELIVERY', 'POS']) then begin
            if (ManagerKey <> '') and not onlycalculate then begin
                CSWEB.Reset();
                CSWEB.SetCurrentKey(Date, time);
                CSWEB.SetRange(Date, Today);
                CSWEB.SetRange("order No.", ManagerKey);
                if CSWEB.FindFirst() and (CSWEB.Amount <> 0) then
                    exit(CSWEB.LastSlipNo);
            end;
        end;

        if MembershipCard.Get(MemberCard) then begin
            CustDiscGroupTemp := '';
            if MemberAcc2.Get(MembershipCard."Account No.") then
                Customer := MemberAcc2."Linked To Customer No.";
        end;

        for i := 1 to ArrayLen(Arr_Item) do
            if (Arr_Item[i] = 'A7436') or (Arr_Item[i] = 'A6454') then
                CustDiscGroupTemp := 'VIP';

        if (gRequestFromID in ['DELIVERY']) and not OnlyCalculate then
            if Customer = '' then begin
                Response_Code := '0004';
                Response_Text := lText005;
                exit;
            end;
        //ECOMMERCE+


        if (TransactorText = '') and not (gRequestFromID in ['DELIVERY', 'POS']) then
            if PreBillerExt.ValidateCalculateProcess(gRequestFromID, OnlyCalculate, MemberCard, Arr_Item, Arr_EntryType, ManagerKey) then begin
                PreBillerExt.CalculateDiscount(Arr_Item, Arr_Description, Arr_Unit_Of_Measure, Arr_Qty, Arr_EntryType, Customer, Arr_UnitPriceincVAT, Arr_Discount, Arr_Amount, Arr_EffDisc, Arr_EffAmt, TotalDiscount, TotalAmount, Balance, BalanceVIP, MemberCard);
                //Response_Text := 'TEST';//TESTING
                exit;
            end;

        if not CreateHeader(Store, Terminal, SalesStaff, SalesStaff, ManagerKey, Customer, MemberCard, CustDiscGroupTemp, MemberPoints, RequestFromID, OnlyCalculate, Response_Code, Response_Text) then begin
            DeletePOSTransaction(ReceiptNo_g);
            exit('');
        end;

        if POSTransaction_l.Get(ReceiptNo_g) then begin
            /*if (MemberCard <> '') then
                //if not POSTransactionCU.CheckMemberCard() then begin
                if not CustomCheckMemberCard(MemberCard, POSTransaction_l) then begin
                    Response_Code := '0070';
                    Response_Text := StrSubstNo(gText005, MemberCard, POSSession.GetValue('TS_ERRor'));
                    DeletePOSTransaction(ReceiptNo_g);
                    exit('');
                end;*///TEMPORAL VALIDAR DESCUENTOS EN GLOBAL

            Clear(ArrSpecialAction);
            TotalLines := Arraylen(Arr_Item);
            for i := 1 to TotalLines do
                if (Arr_EntryType[i] = 6) and (Arr_Item[i] = 'VIPBAC') then
                    ArrSpecialAction[1] := true
                else
                    if (Arr_Item[i] = 'A7436') or (Arr_Item[i] = 'A6454') then
                        ArrSpecialAction[2] := true;

            if ArrSpecialAction[1] and ArrSpecialAction[2] then begin
                POSTransaction_l.Get(ReceiptNo_g);
                POSTransaction_l."Customer No." := 'MI PROMO';
                POSTransaction_l.Modify();
                Customer2.Get(POSTransaction_l."Customer No.");
                Customer1.Get(Customer);
                Customer2.Validate(Customer2.Name, Customer1.Name);
                Customer2."FSN DUI" := Customer1."FSN DUI";
                Customer2.Modify(true);
                Commit();
            end;

            if ArrSpecialAction[1] then begin
                for i := 1 to TotalLines do
                    if not (Arr_Item[i] in ['A7436', 'A6454']) and (Arr_EntryType[i] = 0) then
                        ArrSpecialAction[3] := true;
                if ArrSpecialAction[3] then begin
                    Response_Code := '0073';
                    Response_Text := lText009;
                    DeletePOSTransaction(ReceiptNo_g);
                    exit('');
                end;
            end;
        end;

        if POSTransactionTB.Get(ReceiptNo_g) then begin
            paymentPosition := PreBillerExt.getIndex(Arr_EntryType, 1);
            if customer_temp.Get(Customer) then;
            if (Arr_Item[paymentPosition] = '4') and (customer_temp."Customer Posting Group" <> 'EMPLEADOS') and (POSTransactionTB."Customer Disc. Group" = 'VIP') then begin
                POSTransactionTB."Customer Disc. Group" := 'RETAIL';
                POSTransactionTB.Modify(true);
            end;
            TransCustomerDiscGroup := POSTransactionTB."Customer Disc. Group";

            POSTransLineTB.Reset();
            POSTransLineTB.SetRange("Receipt No.", ReceiptNo_g);
            if POSTransLineTB.FindLast() then
                Line := POSTransLineTB."Line No." + 10000
            ELSE
                Line := 10000;

            LineExchange := 10000;
            if not OnlyCalculate then begin
                ExchanGetransLine_l.Reset();
                ExchanGetransLine_l.SetRange(ExchanGetransLine_l."Receipt No.", POSTransactionTB."Receipt No.");
                ExchanGetransLine_l.DeleteAll();
            end;

            TotalLines := ArrayLen(Arr_Item);
            for i := 1 to TotalLines do begin
                if (Arr_EntryType[i] in [102]) and not OnlyCalculate then begin
                    AddLinePosExch(LineExchange, Arr_Item[i], Arr_Unit_Of_Measure[i], Arr_Qty[i], Arr_EntryType[i], COPYSTR(Arr_Description[i], 1, 20), Response_Code, Response_Text);
                    LineExchange += 10000;
                end;
                if Arr_EntryType[i] in [0, 6, 1, 103] then begin
                    if Arr_Item[i] <> '' then //Filter data only
                        case Arr_EntryType[i] of
                            0, 6:
                                begin//180725
                                    ValidateItem(POSTransactionTB."Receipt No.", Arr_Item[i], Arr_Unit_Of_Measure[i], Arr_Qty[i], POSTransactionTB."Customer No.", POSTransactionTB."FSN Remission No.", Response_Code, Response_Text);

                                    if Response_Code = '0000' then begin
                                        GLOBALDESCRIPTIONV := CopyStr(Arr_Description[i], 1, 100);
                                        AddLine(Line, Arr_Item[i], Arr_Unit_Of_Measure[i], Arr_Qty[i], Arr_EntryType[i], Response_Code, Response_Text);
                                    end;
                                end;
                            1:
                                begin
                                    TenderCode := ValidatePaymentLine(Arr_Item[i], Store, Response_Code, Response_Text);
                                end;
                            103:
                                begin
                                    if not OnlyCalculate then
                                        if not AddLineinfocode(CopyStr(Arr_Item[i], 1, 10), CopyStr(Arr_Description[i], 1, 50), Response_Text, Arr_Qty[i]) then
                                            Response_Code := '0003';
                                end;
                        end;

                    if Response_Code <> '0000' then
                        i := ArrayLen(Arr_Item);

                    if i = TotalLines then
                        Line += 30000
                    else
                        if Arr_EntryType[i + 1] = 6 then
                            Line += 10000
                        else
                            Line += 30000;
                end;
            end;

            //aplicar cupon de cambio de oferta
            if (gRequestFromID in ['DELIVERY', 'POS']) then
                if (TenderCode = '5') and (Couponheader_l.Get('VIPAGRI')) and (CouponHeader_l.Status = CouponHeader_l.Status::Enabled) then begin
                    Line += 10000;
                    AddLine(Line, CouponHeader_l.Code, '', 1, 6, Response_Code, Response_Text);
                    Response_Code := '0000';
                    Clear(Response_Text);
                    couponChangeOffer := true;
                end;

            //aplicar los otros descuentos cuando no se cambio la oferta
            if (gRequestFromID in ['DELIVERY', 'POS']) then
                if (RequestFromID <> '') and (Bincoupon.Get(CopyStr(RequestFromID, 1, 6))) and not couponChangeOffer then begin
                    if (BINcoupon."Coupon Code" <> '') and (TenderCode in ['20', '5']) then begin
                        Line += 10000;
                        AddLine(Line, CopyStr(Bincoupon."Coupon Code", 1, 10), '', 1, 6, Response_Code, Response_Text);
                        Response_Code := '0000';
                        clear(Response_Text);
                    end;
                end;

            if Response_Code <> '0000' then begin
                POSTransactionTB.Get(ReceiptNo_g);
                POSTransactionTB.Delete(true);
                exit('');
            end;

            if (Customer <> '') then //and not OnlyCalculate and (MemberCard = '') then
                if not AddCustLine(Line, Response_Code, Response_Text) then begin
                    DeletePOSTransaction(ReceiptNo_g);
                    exit('');
                end;

            PosPrice.CalcPeriodicOnTotalPressed(POSTransactionTB);

            cuponManagement.ApplyCouponsToTransaction(POSTransactionTB, TRUE, FAlSE); //olopez
            POSTransLineTB.Reset();
            POSTransLineTB.SetRange(POSTransLineTB."Receipt No.", ReceiptNo_g);
            POSTransLineTB.SetRange(POSTransLineTB."Entry Type", POSTransLineTB."Entry Type"::Coupon);
            POSTransLineTB.SetRange(POSTransLineTB."Entry Status", 0);
            POSTransLineTB.SetRange(POSTransLineTB."Valid in Transaction", FALSE);
            POSTransLineTB.DeleteAll(true);

            POSTransactionTB.Get(ReceiptNo_g);
            POSTransactionTB."Entry Status" := POSTransactionTB."Entry Status"::Suspended;
            POSTransactionTB."Starting Point Balance" := MemberPoints;
            POSTransactionTB.Modify();//estaba comentado

            if ((TenderCode <> '') and OnlyCalculate) or not (gRequestFromID in ['POS']) then begin
                POSTransLineTEMP_l.Reset();
                POSTransLineTEMP_l.DeleteAll();
                PosFunc.RecalcSlip(POSTransactionTB);
                POSOfferExtUtil.ReCalcOfferSeq(POSTransactionTB, OfferType::"Total Discount");

                //Total VIP
                if (TenderCode <> '') and OnlyCalculate then
                    if POSTransactionTB."Customer Disc. Group" in ['RETAIL', ''] then begin
                        POSTransactionTB.Get(ReceiptNo_g);
                        Custom2Code := POSTransactionTB."Customer No.";
                        POSTransactionTB."Customer Disc. Group" := _VIP;
                        POSTransactionTB."Customer No." := 'V1';
                        POSTransactionTB.Modify();
                        RecalcProcess();

                        POSOfferExtUtil.GetPopUpTenderTypeOffer(POSTransactionTB, TenderCode, POSTransLineTEMP_l);
                        if POSTransLineTEMP_l.FinDFIRST then
                            BalanceVIP := POSTransLineTEMP_l.Amount
                        else begin
                            POSTransactionTB.CALCFIELDS("Gross Amount");
                            BalanceVIP := POSTransactionTB."Gross Amount";
                        end;
                        POSTransactionTB."Customer Disc. Group" := TransCustomerDiscGroup;
                        POSTransactionTB."Customer No." := Custom2Code;
                        POSTransactionTB.Modify();
                        RecalcProcess();
                    END;
                //Total VIP
                POSTransLineTEMP_l.Reset();
                POSTransLineTEMP_l.DeleteAll();
                POSOfferExtUtil.GetPopUpTenderTypeOffer(POSTransactionTB, TenderCode, POSTransLineTEMP_l);

                Line += 10000;
                POSTransLineTB.Init();
                if POSTransLineTEMP_l.FindSet() then begin
                    POSTransLineTB := POSTransLineTEMP_l;
                end else begin
                    POSTransactionTB.CalcFields(POSTransactionTB."Gross Amount");
                    POSTransLineTB.Amount := POSTransactionTB."Gross Amount";
                    POSTransactionTB.CalcFields(POSTransactionTB."Line Discount");
                    POSTransLineTB."Discount Amount" := POSTransactionTB."Line Discount";
                    POSTransLineTB.Number := TenderCode;
                    if TenderTypeS_l.Get(POSTransactionTB."Store No.", TenderCode) then;
                    POSTransLineTB.Description := TenderTypeS_l.Description;
                end;

                POSTransLineTB."Receipt No." := ReceiptNo_g;
                POSTransLineTB."Store No." := POSTransactionTB."Store No.";
                POSTransLineTB."POS Terminal No." := POSTransactionTB."POS Terminal No.";
                //olopez POSTransLineTB."Line No." := Line;
                POSTransLineTB."Parent Line" := Line;
                POSTransLineTB.Quantity := 1;
                POSTransLineTB.Price := 0;
                POSTransLineTB."Trans. Date" := TODAY;
                POSTransLineTB."Trans. Time" := TIME;
                POSTransLineTB."Entry Type" := POSTransLineTB."Entry Type"::Payment;
                POSTransLineTB.insertLine();

                POSOfferExtUtil.ProcessTenderTypeOffer(POSTransactionTB);

                if (TenderCode <> '') and OnlyCalculate then begin
                    POSTransactionCU.SetPOSState('SALES');
                    POSTransactionCU.CalcTotals;

                    TotalAmount += POSTransLineTB.Amount + POSTransLineTB."Discount Amount";
                    TotalDiscount += -POSTransLineTB."Discount Amount";
                    //TotalDiscount := TotalDiscount + (-POSTransLineTB."Discount Amount");
                    Balance := TotalAmount + TotalDiscount;
                    if BalanceVIP = 0 then
                        BalanceVIP := Balance;

                    i := 1;

                    CompressArrayProcess();
                    Clear(Arr_Item);
                    Clear(Arr_Unit_Of_Measure);
                    Clear(Arr_Qty);
                    Clear(Arr_EntryType);
                    Clear(Arr_Description);
                    Clear(Arr_UnitPriceincVAT);
                    Enuminteger := 0;

                    CompressTransLine.Reset();
                    //CompressTransLine.SetRange(CompressTransLine."Entry Type", POSTransLinbe."Entry Type"::Item);
                    CompressTransLine.SetRange("Receipt No.", ReceiptNo_g);
                    IF CompressTransLine.FIND('-') THEN BEGIN
                        REPEAT
                            if CompressTransLine."Entry Type" = CompressTransLine."Entry Type"::Coupon then begin
                                Arr_Qty[i] := 1;
                                Arr_Item[i] := CompressTransLine."Coupon Code";
                            end else begin
                                Arr_Item[i] := CompressTransLine.Number;
                                Arr_Qty[i] := CompressTransLine.Quantity;
                            end;
                            Arr_UnitPriceincVAT[i] := CompressTransLine.Price;
                            Arr_Description[i] := CompressTransLine.Description;
                            Arr_Unit_Of_Measure[i] := CompressTransLine."Unit of Measure";
                            Enuminteger := CompressTransLine."Entry Type".Asinteger();
                            Arr_EntryType[i] := Enuminteger;
                            Arr_Discount[i] := CompressTransLine."Discount %";
                            Arr_Amount[i] := CompressTransLine."Discount Amount";

                            Arr_EffDisc[i] := 0;
                            Arr_EffAmt[i] := 0;

                            i := i + 1;
                        UNTIL CompressTransLine.NEXT() = 0;
                    END;


                    /*CompressTransLine.Reset();
                    if CompressTransLine.FindSet() then
                        repeat
                            if CompressTransLine."Entry Type" = CompressTransLine."Entry Type"::Coupon then begin
                                Arr_Qty[i] := 1;
                                Arr_Item[i] := CompressTransLine."Coupon Code";
                            end else begin
                                Arr_Item[i] := CompressTransLine.Number;
                                Arr_Qty[i] := CompressTransLine.Quantity;
                            end;
                            Arr_UnitPriceincVAT[i] := CompressTransLine.Price;
                            Arr_Description[i] := CompressTransLine.Description;
                            Arr_Unit_Of_Measure[i] := CompressTransLine."Unit of Measure";
                            Enuminteger := CompressTransLine."Entry Type".Asinteger();
                            Arr_EntryType[i] := Enuminteger;
                            Arr_Discount[i] := CompressTransLine."Discount %";
                            Arr_Amount[i] := CompressTransLine."Discount Amount";

                            Arr_EffDisc[i] := 0;
                            Arr_EffAmt[i] := 0;

                            i := i + 1;
                        until CompressTransLine.NEXT = 0;*/
                    Response_Text := GLOBALPROCESLOT;
                    //GLOBALPROCESLOT := '';
                    POSTransactionCU.SetPOSState('SALES');
                    POSTransactionCU.CalcTotals;
                end;
            end;

            Commit();
            if OnlyCalculate then
                DeletePOSTransaction(ReceiptNo_g)
            else begin
                if not (gRequestFromID in ['POS']) then begin//ECOMMERCE-

                    POSMenuLine."Current-RECEIPT" := POSTransactionTB."Receipt No.";
                    IF gRequestFromID = 'DELIVERY' THEN
                        POSMenuLine.Parameter := RequestFromID
                    ELSE
                        POSMenuLine.Parameter := COPYSTR(RequestFromID, 1, 6);
                    POSMenuLine."Post Parameter" := ManagerKey; //Order No.
                    POSMenuLine."Current-SALESorDER" := TenderCode;

                    if not (gRequestFromID in ['POS']) and not OnlyCalculate then begin //ECOMMERCE
                        Tcommand := 'JSON_BITWORKS';

                        Clear(Processed);
                        FSNUtil.OninvokeGlobalChannelEvent(TransactorText, Tresponse, Tcommand, POSMenuLine, Processed, Response_Text);

                        if not Processed then begin
                            Response_Code := '0053';
                            Response_Text := StrSubstNo(ErrorOninvokeGlobalChannelEvent, Tcommand);
                            DeletePOSTransaction(ReceiptNo_g);
                            exit('');
                        end;
                    end;

                    if POSTransactionTB.Get(ReceiptNo_g) then;
                    CLEAR(TableRequestStatus);
                    JsonToXmlFillTableTransactorNode(POSMenuLine, TransactorText, TableRequestStatus);
                    if not TableRequestStatus.Get(POSTransactionTB."Receipt No.") then begin
                        Response_Code := '0999';
                        Response_Text := STRSUBSTNO(lText007);
                        DeletePOSTransaction(ReceiptNo_g);
                        exit('');
                    end;

                    TableRequestStatus.Store := POSTransactionTB."Store No.";
                    TableRequestStatus.Terminal := POSTransactionTB."POS Terminal No.";
                    TableRequestStatus."Status WS" := TableRequestStatus."Status WS"::Pending;
                    TableRequestStatus."order No." := ManagerKey;
                    TableRequestStatus.Date := TODAY;
                    TableRequestStatus.Time := TIME;
                    TableRequestStatus."WS Request" := 'SEND_POSTRANS_BACKUP';
                    if TableRequestStatus.Modify() then;

                    if not (TableRequestStatus.Store in ['EC', 'APP']) then begin
                        if not (gRequestFromID in ['DELIVERY', 'POS']) then begin
                            Pago_l.Reset();
                            Pago_l.SetRange(Pago_l."Receipt No.", POSMenuLine."Current-RECEIPT");
                            Pago_l.SetRange("Entry Type", TrasLineEntryEnum::Payment);
                            if not Pago_l.Find('-') then begin
                                Response_Code := '0999';
                                Response_Text := StrSubstNo(lText008, gRequestFromID, TransactorText);
                                DeletePOSTransaction(ReceiptNo_g);
                                exit('');
                            end;
                        end;
                    end;
                    Commit();

                    if not (gRequestFromID in ['POS']) and not OnlyCalculate then begin //ECOMMERCE
                        POSMenuLine."Current-RECEIPT" := POSTransactionTB."Receipt No.";

                        Tcommand := 'SEND_POSTRANS_BACKUP';
                        POSTransactionTMP.Copy(POSTransaction_l);
                        POSTransactionTMP."Manager ID" := ManagerKey;
                        RecRef.GetTable(POSTransactionTMP);
                        Clear(Processed);
                        FSNUtil.OninvokeGlobalChannelEvent(TransactorText, Tresponse, Tcommand, POSMenuLine, Processed, Response_Text);

                        //if not Processed then begin
                        if gRequestFromID in ['DELIVERY'] then begin //if DELIVERY ONLY
                            if PosTransaction4.Get(POSMenuLine."Current-RECEIPT") and
                              not (Deliveryorder4.Get(POSMenuLine."Current-RECEIPT")) then begin
                                Response_Code := '0999';
                                Response_Text := STRSUBSTNO(lText006);
                                DeletePOSTransaction(ReceiptNo_g);
                                exit('');
                            end;
                        end;
                    end;
                end;//ECOMMERCE+
                Response_Text := GLOBALPROCESLOT;
                GLOBALPROCESLOT := '';
                exit(ReceiptNo_g);
            end;
            Commit();
        end;
    end;

    procedure ValidateItem(Receipt: Code[20]; Number: Code[20]; UnitofMeasure: Code[10]; Quantity: Decimal; CustomerNo: Code[20]; Processed: Boolean; var ResponseCode: Text[10]; var MsgResult: text)
    var
        ErrorText: Text;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        FSNUtility: Codeunit "FSN Utility";
    begin
        //180725
        MsgResult := '';
        RequestID := 'FSNBLOCKITEM';
        XMLResponse := Receipt;
        Processed := false;
        PosMenuLineTemp."Profile ID" := 'FASANI';
        PosMenuLineTemp."Menu ID" := 'FSNBLOCKITEM';
        PosMenuLineTemp."Key No." := '1';
        PosMenuLineTemp.Command := Number;
        PosMenuLineTemp."POS Help ID" := UnitofMeasure;
        PosMenuLineTemp."Current-Price" := Quantity;
        PosMenuLineTemp."Post Command" := CustomerNo;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        if MsgResult <> '' then
            ResponseCode := '2898'
        else
            ResponseCode := '0000';
    end;

    procedure ArrJSON(JsonInput: Text; var lot: Code[20]; var DateExp: Date; ItemVal: Code[20]; Receipt: Code[20]; var LineNo: Integer): Boolean
    var
        JsonObj: JsonObject;
        JsonArray: JsonArray;
        JsonToken: JsonToken;
        JsonItem: JsonObject;
        DueDateText: Text;
        Datef: Date;
        NewJsonInput: text;
        p: File;
        o: OutStream;
        sb: DotNet StringBuilder;
        POSTransLine: Record "LSC POS Trans. Line";
    begin

        NewJsonInput := '{"Arreglo":' + JsonInput + '}';

        // Leer el JSON de entrada
        if JsonObj.ReadFrom(NewJsonInput) then
            if JsonObj.Get('Arreglo', JsonToken) then // Seleccionar el arreglo "Arreglo
                if JsonToken.IsArray then begin  // Verificar que el token es un arreglo y convertirlo

                    JsonArray := JsonToken.AsArray();

                    // Iterar sobre los elementos del arreglo
                    foreach JsonToken in JsonArray do begin

                        if JsonToken.IsObject then begin // Verificar que sea un objeto
                            JsonItem := JsonToken.AsObject();

                            // Comparar el valor de "Item"
                            if JsonItem.Get('Item', JsonToken) and (JsonToken.AsValue().AsText() = ItemVal) then begin
                                if JsonItem.Get('Key', JsonToken) then
                                    LineNo := JsonToken.AsValue().AsInteger();
                                POSTransLine.Reset();
                                POSTransLine.SetRange(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
                                POSTransLine.SetRange(POSTransLine."Receipt No.", Receipt);
                                POSTransLine.SetRange(POSTransLine."Line No.", LineNo);
                                POSTransLine.SetRange(POSTransLine.Number, ItemVal);
                                if not (POSTransLine.FindFirst()) then begin
                                    // Obtener el valor de "Lote"
                                    if JsonItem.Get('Lote', JsonToken) then
                                        lot := JsonToken.AsValue().AsText();

                                    // Obtener el valor de "DueDate"
                                    if JsonItem.Get('DueDate', JsonToken) then begin
                                        DueDateText := JsonToken.AsValue().AsText();
                                        if Evaluate(Datef, DueDateText) then
                                            DateExp := Datef
                                        else
                                            DateExp := 0D;
                                    end;
                                    exit(true);
                                end;
                            end
                        end;
                    end;
                end;
        exit(false);
    end;
    /*
    procedure EditNonPaymentTrack(pTrack: Text) rTrack: Text;
    var
        PosSetup: Record "LSC POS Hardware Profile";
        tmpToPosition: integer;
    begin

        if PosSetup."Start from Position" > 0 then
            if PosSetup."Start from Position" < STRLEN(rTrack) then
                rTrack := COPYSTR(rTrack, PosSetup."Start from Position");

        if PosSetup."End at Char" <> '' then
            tmpToPosition := STRPOS(rTrack, PosSetup."End at Char") - 1;

        if PosSetup."End at Position" > 0 then begin
            if tmpToPosition > 0 then begin
                if PosSetup."End at Position" < tmpToPosition then
                    tmpToPosition := PosSetup."End at Position";
            END
            ELSE
                tmpToPosition := PosSetup."End at Position";
        END;

        if tmpToPosition > 0 then
            rTrack := COPYSTR(rTrack, 1, tmpToPosition);

        EXIT(rTrack);
    end;
    */
    procedure Trim(String_in: Text; Len: integer): Text[1024];
    begin
        EXIT(DELCHR(COPYSTR(String_in, 1, Len), '>', ' '));
    end;

    procedure ValidateAgricolaCard(Bin: Code[6]): Boolean
    var
        BinList: Record "FSN Bin Bank";
    begin
        if not BinList.Get(Bin) then
            EXIT(FALSE);

        if BinList."Tender Type Default" <> '5' then
            EXIT(FALSE);

        EXIT(TRUE);
    end;

    procedure ValidateGiftCard
    (
        Number: Code[20];
        var LastNumber: Code[20];
        var LastValidDate: Text[20];
        var Balance: Decimal;
        var Response_Code: Text[10];
        var Response_Text: Text
    )
    var
        SqlConnect: DotNet SqlConnect;
        SqlCommand: DotNet SqlCmd;
        SqlDataReader: DotNet SqlDataRdr;
        Store_l: Record "LSC Store";
        RetailSeup_l: Record "LSC Retail Setup";
        PosFuncProfile: Record "LSC POS Func. Profile";
        POSFuncProfileWebServer: Record "LSC POS Func. Profile Web Serv";
        POSFuncProfileWebReq: Record "LSC POS Func. Profile Web Req.";
        DisLocation: Record "LSC Distribution Location";
        WebServicesClient: Codeunit "LSC Web Services Client";
        POSTransactionServerUtil: Codeunit "LSC POS Trans. Server Utility";
        ConnectionString: Text[125];
        SqlString: Text;
        ForCount: integer;
        ProcessError: Boolean;
        lTextConn: Label 'Data Source=%1;initial Catalog=%2;integrated Security=false; User ID=%3;Password=%4;';
        lText001: Label 'Tarjeta %1 no es valida (%2)';
        lText002: Label 'No Existe';
        lText003: Label 'Esta vencida. Expiró %1';
        lText004: Label 'DUI %1 No corresponde a la VIP %2';
        lText005: Label 'Debe definir un numero de GiftCard para la busqueda';
        lText006: Label 'Error en el servidor para consultas GiftCard (Configuración)';
        lTextSimbol: Label '''''';
    begin
        Response_Code := '0000';
        Response_Text := '';
        Balance := 0;
        LastNumber := '';
        LastValidDate := '';
        ProcessError := FALSE;

        if Number = '' then begin
            Response_Code := '0010';
            Response_Text := lText005;
            EXIT;
        END;

        ProcessError := RetailSeup_l.Get;
        if not ProcessError then
            ProcessError := Store_l.Get(RetailSeup_l."Local Store No.");
        if not ProcessError then
            ProcessError := PosFuncProfile.Get(Store_l."Functionality Profile");
        if not ProcessError then
            ProcessError := POSFuncProfileWebReq.WebRequestActive(Store_l."Functionality Profile", 'Get_DATA_ENTRY_BALANCE');

        POSFuncProfileWebServer.Reset();
        POSFuncProfileWebServer.SETCURRENTKEY("Profile ID", "Request ID", Priority);
        POSFuncProfileWebServer.SetRange(POSFuncProfileWebServer."Profile ID", PosFuncProfile."Profile ID");
        POSFuncProfileWebServer.SetRange(POSFuncProfileWebServer."Request ID", 'FSN_Get_ACCOUNT_inFO');
        if not ProcessError then
            ProcessError := POSFuncProfileWebServer.FinDFIRST;
        if not ProcessError then
            ProcessError := DisLocation.Get(POSFuncProfileWebServer."Dist. Location");


        if ProcessError then begin
            Response_Text := lText006;
            Response_Code := '0020';
            EXIT;
        END;

        ForCount := 0;

        ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password); //olopez
        SqlConnect := SqlConnect.SqlConnection(ConnectionString);

        SqlString := 'SELECT TOP 1 Balance,LastDate FROM (SELECT SUM(v.Amount) Balance, ' +
          'CASE WHEN p.[Expiring Date] = ''01/01/1753'' then ''01/01/2100'' ELSE p.[Expiring Date] END LastDate ' +
          'FROM [FASANI$POS Data Entry] p JOin [FASANI$Voucher Entries] v ON p.[Entry Code] = v.[Voucher No_] ' +
          'and p.[Entry Code] = ' + Number + ' and Voided = 0 GROUP BY [Expiring Date]) Gifts orDER BY Gifts.LastDate DESC';


        SqlConnect.Open();
        SqlCommand := SqlConnect.CreateCommand();
        SqlCommand.CommandText := SqlString;
        SqlDataReader := SqlCommand.ExecuteReader();
        WHILE SqlDataReader.Read() and (ForCount < 1) DO begin
            Balance := SqlDataReader.Item('Balance');
            LastValidDate := SqlDataReader.Item('LastDate');
            ForCount += 1;
        END;
        SqlDataReader.Close();
        SqlConnect.Close();

        if ForCount = 0 then begin
            Response_Code := '0030';
            Response_Text := STRSUBSTNO(lText001, Number, lText002);
        END;
    end;

    procedure ValidatePaymentLine
    (
        "code": Code[10];
        Store: Code[10];
        var Response_Code: Text[10];
        var Response_Text: Text
    ) Tender: Code[10];
    var
        TenderTypeREC: Record "LSC Tender Type";
    begin
        if TenderTypeREC.Get(Store, code) then
            exit(TenderTypeREC.Code);

        Response_Code := '0070';
        Response_Text := StrSubstNo(gText001, code, TenderTypeREC.TABLECAPTION);
        exit('');
    end;

    procedure WSXMLStandar(var XMLRequest: Text; var XMLResponse: Text; var RequestID: Text[50]): Text
    var
        XMLStandar: Codeunit "FSN WS XML Remss. integration";
        Handled: Boolean;
        FSNUtility: Codeunit "FSN Utility";
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: boolean;
        MsgResult: text;
        p: File;
        o: OutStream;
        sb: DotNet StringBuilder;
    begin
        Handled := false;
        OnWSXmlStandarRun(XMLRequest, XMLResponse, RequestID, Handled);

        if (Handled) then
            exit;
        if RequestID in ['FSN_ECOMM_ITEMCROSS_X', 'FSN_ECOMM_CHECK_DELSTORE_X', 'FSN_ECOMM_CHECK_DELTAKEAWAY_X'] then begin
            XMLResponse := EcommerceFunctions(XMLRequest, XMLResponse, RequestID);
            exit(XMLResponse);
        end;

        if RequestID = 'FSN_CHECK_RIFAS_TRANSAC' then begin
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            exit('');
        end;

        XMLStandar.SetXMLRequest(XMLRequest, RequestID);
        XMLStandar.RUN();
        XMLStandar.GetXMLResponse(XMLResponse, RequestID);
    end;

    /// <summary>
    /// getDistrict.
    /// this procedure generate a json array with the district list.
    /// </summary>
    /// <returns>Return value of type Text.</returns>
    [ServiceEnabled]
    procedure getDistrict(): Text
    var
        array: JsonArray;
        object: JsonObject;
        postCode: Record "Post Code";
        txt: Text;
    begin
        array.WriteTo(txt);
        if not postCode.Find('-') then
            exit(txt);

        repeat
            Clear(object);
            object.Add('code', postCode.Code);
            object.Add('district', postCode.County);
            array.Add(object);
        until postCode.Next() = 0;

        array.WriteTo(txt);
        exit(txt);
    end;
    #endregion
    #region [Comment Methods]
    /*
        procedure GetReceiptNo(var LastReceiptNo: Code[20]; RequestFromID_l: Code[20]; CalcOnly: Boolean) LastRcpt: Code[20]
        begin
            if CalcOnly then begin
                LastReceiptNo := PosFunc.ZeroPad(POSSession.TerminalNo, 10) + RequestFromID_l + '01';
            END ELSE
                PosFunc.ReadLocalVar(LastReceiptNo);
            EXIT(LastReceiptNo);
        end;
    */

    local procedure EcommerceFunctions(var XMLRequest: Text; var XMLResponse: Text; var RequestID: Text[50]): Text
    var
        Processed: Boolean;
        MsgResult: Text;
        pPosMenuLineTmp: Record "LSC POS Menu Line" temporary;

    begin
        FSNUtil.OninvokeGlobalChannelEvent(XMLRequest, XMLResponse, RequestID, pPosMenuLineTmp, Processed, MsgResult);
        exit(XMLResponse);
    end;

    #endregion
    #region [Subscriptions]


    [EventSubscriber(ObjectType::Table, Database::"FSN Replen. Sales Adj. Line", 'OnAfterValidateEvent', 'Item No.', true, true)]
    local procedure "FSN Replen. Sales Adj. Line_OnAfterValidateEvent_Item No."
    (
        var Rec: Record "FSN Replen. Sales Adj. Line";
        var xRec: Record "FSN Replen. Sales Adj. Line";
        CurrFieldNo: Integer
    )
    var
        Item: Record Item;
    begin
        if Item.Get(Rec."Item No.") then
            Rec.Description := Item.Description;

        xRec.Reset();
        xRec.SetRange("Item No.", Rec."Item No.");
        xRec.SetRange("Location Code", Rec."Location Code");
        xRec.SetRange(Date, Today);
        if xRec.FindLast() then
            Rec."Line No." := xRec."Line No." + 10000
        else
            Rec."Line No." := 10000;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Data Table SourceExpr Util", 'OnGetSourceExpr', '', true, true)]
    local procedure "LSC Data Table SourceExpr Util_OnGetSourceExpr"
    (
        var Handled: Boolean;
        var returnTxt: Text;
        var pLookupSetupID: Code[10];
        var pSourceExprID: Code[10];
        var pRecRef: RecordRef;
        var pPosTransLine: Record "LSC POS Trans. Line"
    )
    begin
        if pSourceExprID = 'GETNOMCL' then begin
            returnTxt := GetNombreCliente(pRecRef);
            Handled := true;
        end
    end;

    #endregion
    #region [Events]
    [integrationEvent(true, false)]
    procedure OnWSXmlStandarRun(var XMLRequest: Text; var XMLResponse: Text; var RequestID: Text[50]; var IsHandled: Boolean);
    begin
    end;
    #endregion
}