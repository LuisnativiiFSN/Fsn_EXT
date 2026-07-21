xmlport 50002 "FSN XmlPortTransactionReport"
{
    schema
    {
        tableelement("TransactionHeaderExt"; "FSN Transaction Header Ext")
        {
            MinOccurs = Zero;
            XmlName = 'ImprimirDocumento';
            UseTemporary = true;

            textelement(datosGenerales)
            {
                fieldelement("resolucionCopia"; "TransactionHeaderExt".Resolucion)
                {

                }
                fieldelement("fechaAutorizacion"; TransactionHeaderExt."Fecha Autorizacion")
                {

                }
                fieldelement("serieCopia"; "TransactionHeaderExt".Serie)
                {

                }
                fieldelement("desdeCopia"; "TransactionHeaderExt".Desde)
                {

                }
                fieldelement("hastaCopia"; "TransactionHeaderExt".Hasta)
                {

                }
                fieldelement("ncfCopia"; "TransactionHeaderExt"."Numero de Factura")
                {

                }

                textelement("giroEmpresa")
                {
                    trigger OnBeforePassVariable()
                    begin
                        giroEmpresa := CompanyGlobal."FSN NRC";
                    end;
                }
                textelement("sucursalEmpresa")
                {
                    trigger OnBeforePassVariable()
                    begin
                        sucursalEmpresa := StoreGlobal.Name;
                    end;
                }
                textelement("direccionSucursal")
                {
                    trigger OnBeforePassVariable()
                    begin
                        direccionSucursal := StoreGlobal.Address;
                    end;
                }
                textelement("nitEmpresa")
                {
                    trigger OnBeforePassVariable()
                    begin
                        nitEmpresa := CompanyGlobal."Federal ID No.";
                    end;
                }
                textelement("nrcEmpresa")
                {
                    trigger OnBeforePassVariable()
                    begin
                        nrcEmpresa := CompanyGlobal."FSN NRC";
                    end;
                }
                textelement("nombreCliente")
                {
                    trigger OnBeforePassVariable()
                    begin
                        nombreCliente := NombreGlobal;
                    end;
                }
                textelement(direccionCliente)
                {
                    trigger OnBeforePassVariable()
                    var
                        Customer: Record Customer;
                        TransHeader: Record "LSC Transaction Header";
                    begin
                        if TransHeaderGlobal.Address <> '' then
                            direccionCliente := DELCHR(DELCHR(DELCHR(TransHeaderGlobal.Address, '=', '>'), '=', '<'), '=', '&')
                        else
                            direccionCliente := DELCHR(DELCHR(DELCHR(CustomerGlobal.Address, '=', '>'), '=', '<'), '=', '&');
                    end;
                }
                textelement("titularCliente")
                {
                    trigger OnBeforePassVariable()
                    begin
                        titularCliente := TitualarGlobal;
                    end;
                }
                textelement("beneficiarioCliente")
                {
                    trigger OnBeforePassVariable()
                    begin
                        beneficiarioCliente := BeneficiarioGlobal;
                    end;
                }
                textelement("duiCliente")
                {
                    trigger OnBeforePassVariable()
                    var
                        Customer: Record Customer;
                        TransHeader: Record "LSC Transaction Header";
                    begin
                        if TransHeaderGlobal."FSN DUI" <> '' then
                            duiCliente := TransHeaderGlobal."FSN DUI"
                        else
                            duiCliente := CustomerGlobal."FSN DUI";
                    end;
                }
                textelement("nitCliente")
                {
                    trigger OnBeforePassVariable()
                    begin
                        if TransHeaderGlobal."FSN NIT" <> '' then
                            nitCliente := TransHeaderGlobal."FSN NIT"
                        else
                            nitCliente := CustomerGlobal."VAT Registration No.";
                    end;
                }
                textelement("nrcCliente")
                {
                    trigger OnBeforePassVariable()
                    begin
                        if TransHeaderGlobal."FSN NRC" <> '' then
                            nrcCliente := TransHeaderGlobal."FSN NRC"
                        else
                            nrcCliente := CustomerGlobal."FSN NRC";
                    end;
                }
                textelement("giroCliente")
                {
                    trigger OnBeforePassVariable()
                    begin
                        if TransHeaderGlobal."FSN NRC Description" <> '' then
                            giroCliente := TransHeaderGlobal."FSN NRC Description"
                        else
                            giroCliente := CustomerGlobal."FSN NRC Description";
                    end;
                }
                textelement("fecha")
                {
                    trigger OnBeforePassVariable()
                    var
                    begin
                        fecha := Format("TransactionHeaderExt".Fecha) + ' ' + Format(TransactionHeaderExt.Hora);
                    end;
                }

                textelement("sumas")
                {
                    trigger OnBeforePassVariable()

                    begin
                        if TransHeaderGlobal."FSN Document Type" = TransHeaderGlobal."FSN Document Type"::Factura then begin
                            sumas := DELCHR(Format(Round(-(VATAmt + VATGravado), 0.01) * SimbolGlobal), '=', ',')
                            //sumas := Format(Round(-(VATAmt + VATGravado), 0.01) * SimbolGlobal)
                        end else begin
                            sumas := DELCHR(Format(Round(-(VATGravado), 0.01) * SimbolGlobal), '=', ',')
                            //sumas := Format(Round(-(VATGravado), 0.01) * SimbolGlobal)
                        end;
                    end;
                }
                textelement("ventasNoSujetas")
                {
                    trigger OnBeforePassVariable()
                    begin
                        ventasNoSujetas := '0';
                    end;
                }
                textelement("ventasExentas")
                {
                    trigger OnBeforePassVariable()
                    begin
                        ventasExentas := Format((-Round(VATExento, 0.01)) * SimbolGlobal);
                    end;
                }
                textelement("ventasAfectas")
                {
                    trigger OnBeforePassVariable()
                    begin
                        if TransHeaderGlobal."FSN Document Type" = TransHeaderGlobal."FSN Document Type"::Factura then begin
                            ventasAfectas := DELCHR(Format((-Round(VATGravado + VATAmt, 0.01)) * SimbolGlobal), '=', ',');
                            //ventasAfectas := Format((-Round(VATGravado + VATAmt, 0.01)) * SimbolGlobal)
                        end else begin
                            ventasAfectas := DELCHR(Format((-Round(VATGravado, 0.01)) * SimbolGlobal), '=', ',');
                            //ventasAfectas := Format((-Round(VATGravado, 0.01)) * SimbolGlobal);
                        end;

                    end;
                }
                textelement("subTotal")
                {
                    trigger OnBeforePassVariable()
                    begin
                        if TransHeaderGlobal."FSN Document Type" = TransHeaderGlobal."FSN Document Type"::Factura then begin
                            subTotal := DELCHR(Format(Abs(Round(TransHeaderGlobal.Payment + TransHeaderGlobal."Retencion Amount", 0.01))), '=', ',')
                            //subTotal := Format(Abs(Round(TransHeaderGlobal.Payment + TransHeaderGlobal."Retencion Amount", 0.01)))
                        end else begin
                            subTotal := DELCHR(Format(Abs(Round(VATExento + VATGravado, 0.01))), '=', ',')
                            //subTotal := Format(Abs(Round(VATExento + VATGravado, 0.01)));
                        end;
                    end;
                }

                textelement("ivaNormal")
                {
                    trigger OnBeforePassVariable()
                    begin
                        if TransHeaderGlobal."FSN Document Type" in [TransHeaderGlobal."FSN Document Type"::"Factura"] then
                            ivaNormal := Format(0.00)
                        else
                            ivaNormal := Format(Abs(Round(VATAmt, 0.01)));
                    end;
                }
                textelement("cesc")
                {
                    trigger OnBeforePassVariable()
                    begin
                        cesc := '0';
                    end;
                }
                textelement("ivaRetenido")
                {
                    trigger OnBeforePassVariable()
                    begin
                        ivaRetenido := Format(ABS(TransHeaderGlobal."Retencion Amount"));
                    end;
                }
                textelement("ivaPercibido")
                {
                    trigger OnBeforePassVariable()
                    begin
                        ivaPercibido := Format(ABS(TransHeaderGlobal."Perception Amount"));
                    end;
                }
                textelement("monto")
                {
                    trigger OnBeforePassVariable()
                    begin
                        GlobalMonto := 0;
                        // GlobalMonto se utiliza para mostrar el total en letras.
                        GlobalMonto := (-Round(((VATAmt + VATGravado + VATExento) + TransHeaderGlobal."Retencion Amount" - TransHeaderGlobal."Perception Amount"), 0.01) * SimbolGlobal);
                        monto := DELCHR(Format(-Round(((VATAmt + VATGravado + VATExento) + TransHeaderGlobal."Retencion Amount" - TransHeaderGlobal."Perception Amount"), 0.01) * SimbolGlobal), '=', ',');

                    end;
                }

                fieldelement("pos"; "TransactionHeaderExt"."POS Terminal No.")
                {

                }
                textelement("cajero")
                {
                    trigger OnBeforePassVariable()
                    begin
                        cajero := TransHeaderGlobal."Staff ID";
                    end;
                }
                textelement("vendedor")
                {
                    trigger OnBeforePassVariable()
                    begin
                        vendedor := CopyStr(StaffGlobal, 1, 100);
                    end;
                }
                textelement("formaPago")
                {
                    trigger OnBeforePassVariable()
                    var
                        PaymEntry: Record "LSC Trans. Payment Entry";
                        TenderType: Record "LSC Tender Type";
                        TenderTypeSetupTmp: Record "LSC Tender Type Setup" temporary;
                        TxtPayment: Text;
                    begin
                        Clear(TenderTypeSetupTmp);
                        PaymEntry.RESET;
                        PaymEntry.SETRANGE(PaymEntry."Store No.", TransHeaderGlobal."Store No.");
                        PaymEntry.SETRANGE(PaymEntry."POS Terminal No.", TransHeaderGlobal."POS Terminal No.");
                        PaymEntry.SETRANGE(PaymEntry."Transaction No.", TransHeaderGlobal."Transaction No.");
                        IF PaymEntry.FINDFIRST THEN
                            REPEAT
                                IF TenderType.GET(PaymEntry."Store No.", PaymEntry."Tender Type") THEN
                                    TenderTypeSetupTmp.Code := PaymEntry."Tender Type";
                                TenderTypeSetupTmp.Description := TenderType.Description;
                                if TenderTypeSetupTmp.Insert() then;
                            UNTIL PaymEntry.NEXT = 0;


                        TenderTypeSetupTmp.Reset();
                        if TenderTypeSetupTmp.Find('-') then
                            repeat
                                if TxtPayment = '' then
                                    TxtPayment := TenderTypeSetupTmp.Description
                                else
                                    TxtPayment += ',' + TenderTypeSetupTmp.Description;
                            until TenderTypeSetupTmp.Next() = 0;
                        formaPago := CopyStr(TxtPayment, 1, 100);
                    end;
                }

                textelement("totalLetras")
                {
                    trigger OnBeforePassVariable()
                    var
                        FSNUTILITY: Codeunit "FSN Utility";
                    begin
                        totalLetras := FSNUTILITY.Num2Text(ABS(GlobalMonto)) + ' ' + 'DOLARES';
                    end;
                }
            }


            textelement(listaProductos)
            {

                tableelement(DetalleDocumento; "LSC Trans. Sales Entry")
                {
                    MinOccurs = Zero;
                    XmlName = 'DetalleDocumento';
                    UseTemporary = true;
                    fieldelement("Codigo"; DetalleDocumento."Item No.")
                    {

                    }
                    textelement("Producto")
                    {
                        trigger OnBeforePassVariable()
                        var
                            Item: Record Item;
                            ListaRemision: Record "FSN Remission Header";
                            BarCodes: Record "LSC Barcodes";
                        begin
                            BarCodes.Reset();
                            BarCodes.SetRange(BarCodes."Unit of Measure Code", DetalleDocumento."Unit of Measure");
                            BarCodes.SetRange(BarCodes."Item No.", DetalleDocumento."Item No.");
                            if DetalleDocumento.Counter = 0 then
                                case true of
                                    BarCodes.Find('-'):
                                        Producto := BarCodes.Description;
                                    Item.Get(DetalleDocumento."Item No."):
                                        Producto := Item.Description;
                                end
                            else
                                Producto := DetalleDocumento."Posting Exception Key";
                        end;
                    }
                    textelement("Cantidad")
                    {
                        trigger OnBeforePassVariable()
                        begin
                            /*Cantidad := Format(GetQuantity(DetalleDocumento."Item No.", DetalleDocumento."Unit of Measure"
                                        , DetalleDocumento.Quantity, DetalleDocumento.Counter));**/

                            Cantidad := DELCHR(Format(GetQuantity(DetalleDocumento."Item No.", DetalleDocumento."Unit of Measure"
                            , DetalleDocumento.Quantity, DetalleDocumento.Counter)), '=', ',');
                        end;
                    }
                    textelement("Precio")
                    {
                        trigger OnBeforePassVariable()
                        var
                            Quantity: Integer;
                            DiscAmt: Decimal;
                            UOM: Record "Item Unit of Measure";
                        begin
                            if DetalleDocumento.Counter = 0 then begin
                                if not UOM.Get(DetalleDocumento."Item No.", DetalleDocumento."Unit of Measure") then begin
                                    UOM.Init();
                                    UOM."Qty. per Unit of Measure" := 1
                                end;
                                if UOM."Qty. per Unit of Measure" = 0 then
                                    UOM."Qty. per Unit of Measure" := 1;

                                if TransHeaderGlobal."FSN Document Type" = TransHeaderGlobal."FSN Document Type"::Factura then begin
                                    if (UOM."Qty. per Unit of Measure" > 1) and (DetalleDocumento."UOM Price" <> 0) then
                                        //Precio := Format(Round(+(DetalleDocumento."UOM Price"), 0.01))
                                        Precio := DELCHR(Format(Round(+(DetalleDocumento."UOM Price"), 0.01)), '=', ',')
                                    else
                                        //Precio := Format(Round(+(DetalleDocumento.Price), 0.01));
                                        Precio := DELCHR(Format(Round(+(DetalleDocumento.Price), 0.01)), '=', ',');
                                end else begin
                                    if (UOM."Qty. per Unit of Measure" > 1) and (DetalleDocumento."UOM Price" <> 0) then
                                        //Precio := Format(Round(+(DetalleDocumento."Standard Net Price"), 0.01))
                                        Precio := DELCHR(Format(Round(+(DetalleDocumento."Standard Net Price"), 0.01)), '=', ',')
                                    else
                                        //Precio := Format(Round(+(DetalleDocumento."Net Price"), 0.01))
                                        Precio := DELCHR(Format(Round(+(DetalleDocumento."Net Price"), 0.01)), '=', ',')
                                end;

                                /*
                                if TransHeaderGlobal."FSN Document Type" = TransHeaderGlobal."FSN Document Type"::Factura then
                                    Precio := Format(Round(Abs(((DetalleDocumento."VAT Amount" + DetalleDocumento."Net Amount" - DetalleDocumento."Discount Amount")
                                                / GetQuantity(DetalleDocumento."Item No.", DetalleDocumento."Unit of Measure"
                                                , DetalleDocumento.Quantity, DetalleDocumento.Counter))), 0.01))
                                else begin
                                    DiscAmt := Round(DetalleDocumento."Discount Amount" / (1 + ABS((DetalleDocumento."VAT Amount" / DetalleDocumento."Net Amount"))), 0.01);
                                    Precio := Format(Round(Abs(((DetalleDocumento."Net Amount" - DiscAmt)
                                                  / GetQuantity(DetalleDocumento."Item No.", DetalleDocumento."Unit of Measure"
                                                  , DetalleDocumento.Quantity, DetalleDocumento.Counter))), 0.01));
                                end;*/
                            end else
                                if TransHeaderGlobal."FSN Document Type" = TransHeaderGlobal."FSN Document Type"::Factura then
                                    //Precio := Format(Round(-(DetalleDocumento."VAT Amount" + DetalleDocumento."Net Amount"), 0.01) * SimbolGlobal)
                                    Precio := DELCHR(Format(Round(-(DetalleDocumento."VAT Amount" + DetalleDocumento."Net Amount"), 0.01) * SimbolGlobal), '=', ',')
                                else
                                    Precio := DELCHR(Format(Round(-(DetalleDocumento."Net Amount"), 0.01) * SimbolGlobal), '=', ',');
                            //Precio := DELCHR(Format(Round(-(DetalleDocumento."VAT Amount" + DetalleDocumento."Net Amount"), 0.01) * SimbolGlobal), '=', ',');
                        end;
                    }
                    textelement("Descuento")
                    {
                        trigger OnBeforePassVariable()
                        begin
                            if TransHeaderGlobal."FSN Document Type" = TransHeaderGlobal."FSN Document Type"::Factura then begin
                                Descuento := DELCHR(Format(Round(Abs(DetalleDocumento."Discount Amount"), 0.01)), '=', ',')
                                //Descuento := Format(Round(Abs(DetalleDocumento."Discount Amount"), 0.01));
                            end else
                                if DetalleDocumento."Net Amount" <> 0 then begin
                                    Descuento := DELCHR(Format(Round(ABS(DetalleDocumento."Discount Amount") / (1 + ABS((DetalleDocumento."VAT Amount" / DetalleDocumento."Net Amount"))), 0.01)), '=', ',')
                                    //Descuento := Format(Round(ABS(DetalleDocumento."Discount Amount") / (1 + ABS((DetalleDocumento."VAT Amount" / DetalleDocumento."Net Amount"))), 0.01))
                                end else begin
                                    Descuento := Format(0);
                                end;

                        End;
                    }
                    fieldelement("VentasNoSujetas"; DetalleDocumento."Discount Amt. For Printing")
                    {

                    }
                    fieldelement("VentasExentas"; DetalleDocumento."Infocode Selected Qty.")
                    {
                        trigger OnBeforePassField()
                        begin
                            DetalleDocumento."Infocode Selected Qty." := 0;
                            if DetalleDocumento.Counter = 0 then begin
                                if not VATSetupGlobal.get(DetalleDocumento."VAT Bus. Posting Group", DetalleDocumento."VAT Prod. Posting Group") then
                                    VATSetupGlobal.Init();
                                if VATSetupGlobal."VAT %" = 0 then
                                    DetalleDocumento."Infocode Selected Qty." := -DetalleDocumento."Net Amount" * SimbolGlobal;
                            end else
                                if DetalleDocumento."VAT Amount" = 0 then
                                    DetalleDocumento."Infocode Selected Qty." := -DetalleDocumento."Net Amount" * SimbolGlobal;

                        end;
                    }
                    textelement("VentasAfectas2")
                    {
                        XmlName = 'VentasAfectas';
                        trigger OnBeforePassVariable()
                        var
                            textVar: Text;
                            decVar: Decimal;
                        begin
                            if not VATSetupGlobal.get(DetalleDocumento."VAT Bus. Posting Group", DetalleDocumento."VAT Prod. Posting Group") then
                                VATSetupGlobal.Init();
                            VentasAfectas2 := Format(0);
                            DetalleDocumento."Total Rounded Amt." := 0;

                            if TransHeaderGlobal."FSN Document Type" = TransHeaderGlobal."FSN Document Type"::Factura then begin
                                if DetalleDocumento.Counter = 0 then begin
                                    if VATSetupGlobal."VAT %" <> 0 then
                                        DetalleDocumento."Total Rounded Amt." := -(Round(DetalleDocumento."Net Amount" + DetalleDocumento."VAT Amount")) * SimbolGlobal;
                                    //DetalleDocumento."Total Rounded Amt." := DELCHR(FORMAT(DetalleDocumento."Total Rounded Amt."), '=', ',')
                                end else begin
                                    if DetalleDocumento."VAT Amount" <> 0 then
                                        DetalleDocumento."Total Rounded Amt." := -(Round(DetalleDocumento."Net Amount" + DetalleDocumento."VAT Amount")) * SimbolGlobal;
                                end;
                            end else
                                if DetalleDocumento.Counter = 0 then begin
                                    if VATSetupGlobal."VAT %" <> 0 then
                                        DetalleDocumento."Total Rounded Amt." := -(Round(DetalleDocumento."Net Amount")) * SimbolGlobal;
                                end else begin
                                    if DetalleDocumento."VAT Amount" <> 0 then
                                        DetalleDocumento."Total Rounded Amt." := -(Round(DetalleDocumento."Net Amount")) * SimbolGlobal;

                                end;
                            VentasAfectas2 := Format(DELCHR(FORMAT(Round(DetalleDocumento."Total Rounded Amt.")), '=', ','));
                        end;
                    }
                    textelement("CostoNeto")
                    {
                        trigger OnBeforePassVariable()
                        var
                        begin
                            CostoNeto := '0';
                        end;
                    }
                    textelement("Total")
                    {
                        trigger OnBeforePassVariable()
                        var
                        begin
                            Total := '0';
                        end;
                    }
                }
            }
        }
    }

    requestpage
    {
        layout
        {

        }

        actions
        {
            area(processing)
            {
                action(ActionName)
                {

                }
            }
        }
    }
    var
        TransHeaderGlobal: Record "LSC Transaction Header";
        CustomerGlobal: Record Customer;
        StoreGlobal: Record "LSC Store";
        CompanyGlobal: Record "Company Information";
        TIE: Record "LSC Trans. Inc./Exp. Entry";
        TSE: RECORD "LSC Trans. Sales Entry";
        VATSetupGlobal: Record "VAT Posting Setup";
        NombreGlobal: Text[100];
        SimbolGlobal: Decimal;
        BeneficiarioGlobal: Text[100];
        TitualarGlobal: Text[100];
        StaffGlobal: Text;
        VATExento: Decimal;
        VATGravado: Decimal;
        VATAmt: Decimal;
        GlobalMonto: Decimal;

    [Scope('OnPrem')]
    procedure SetTransaccionHeaderExt(var TransactionHeaderExtTemp: Record "FSN Transaction Header Ext" temporary)
    VAR
        staffTmp: Record "LSC Staff" temporary;
    begin
        Clear(VATExento);
        Clear(VATGravado);
        Clear(CustomerGlobal);
        Clear(StaffGlobal);
        Clear(staffTmp);
        SimbolGlobal := 1;
        if TransactionHeaderExtTemp.Find('=') then
            //repeat
            "TransactionHeaderExt".Init;
        "TransactionHeaderExt" := TransactionHeaderExtTemp;
        "TransactionHeaderExt".Insert;

        TransHeaderGlobal.get(TransactionHeaderExt."Store No.", TransactionHeaderExt."POS Terminal No.", TransactionHeaderExt."Transaction No.");
        if TransHeaderGlobal."Sale Is Return Sale" then
            SimbolGlobal := -1;

        if TransHeaderGlobal."Customer No." <> '' then
            CustomerGlobal.Get(TransHeaderGlobal."Customer No.");

        EncontrarBeneficiario(TransactionHeaderExtTemp);

        StoreGlobal.Get(TransHeaderGlobal."Store No.");
        CompanyGlobal.Get;

        TIE.Reset();
        TIE.SetRange("Store No.", TransHeaderGlobal."Store No.");
        TIE.SetRange("POS Terminal No.", TransHeaderGlobal."POS Terminal No.");
        TIE.SetRange("Transaction No.", TransHeaderGlobal."Transaction No.");
        IF TIE.Find('-') then
            repeat
                VATAmt += TIE."VAT Amount";
                IF TIE."VAT Amount" = 0 then
                    VATExento += TIE."Net Amount"
                else
                    VATGravado += TIE."Net Amount";
            until TIE.Next() = 0;
        TIE.CalcSums("Net Amount", "VAT Amount");
        TSE.Reset();
        TSE.SetRange("Store No.", TransHeaderGlobal."Store No.");
        TSE.SetRange("POS Terminal No.", TransHeaderGlobal."POS Terminal No.");
        TSE.SetRange("Transaction No.", TransHeaderGlobal."Transaction No.");
        if TSE.Find('-') then
            repeat
                VATAmt += TSE."VAT Amount";
                if not VATSetupGlobal.get(TSE."VAT Bus. Posting Group", TSE."VAT Prod. Posting Group") then
                    VATSetupGlobal.Init();

                IF VATSetupGlobal."VAT %" = 0 then
                    VATExento += TSE."Net Amount"
                else
                    VATGravado += TSE."Net Amount";

                staffTmp.ID := TSE."Sales Staff";
                if staffTmp.Insert() then;
            until TSE.Next() = 0;
        staffTmp.Reset();
        if staffTmp.Find('-') then
            repeat
                if StaffGlobal = '' then
                    StaffGlobal := staffTmp.ID
                else
                    StaffGlobal += ',' + staffTmp.ID;
            until staffTmp.Next() = 0;

        DetalleDoc();
    end;

    local procedure DetalleDoc()
    var
        SalesEntry: Record "LSC Trans. Sales Entry";
        TransHeader: Record "LSC Transaction Header";
        TransIncExpEntry: Record "LSC Trans. Inc./Exp. Entry";
        AcoutIncEcp: Record "LSC Income/Expense Account";
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        lRemissionHeader: Record "FSN Remission Header";
        CompanyInsurer: Record "FSN Company Insurer";
        _TextRemission: Text[50];
        _PrintDateRemission: Boolean;
        lCompany: Record "FSN Company Insurer";
        AmountsArr: array[3] of Decimal;
        lRemissionLine: Record "FSN Remission Line";
        TransactionHeaderEx: Record "LSC Transaction Header";
        TransHeaderTemp: Record "LSC Transaction Header" temporary;
        TransInfoEntry: Record "LSC Trans. Infocode Entry";
        TransInfoEntryTemp: Record "LSC Trans. Infocode Entry" temporary;
        RemissionB: Boolean;
        DocumentlineNo: Integer;
    begin
        TransHeaderTemp.RESET;
        TransHeaderTemp.DeleteAll();
        TransInfoEntryTemp.Reset();
        TransInfoEntryTemp.DeleteAll();
        DocumentlineNo := 1;

        TransHeader.GET(TransactionHeaderExt."Store No.", TransactionHeaderExt."POS Terminal No.", TransactionHeaderExt."Transaction No.");
        RemissionB := TransHeader."FSN Remission No.";

        //si es devolucion
        if TransHeader."Sale Is Return Sale" then begin
            if TransHeader."FSN Document Type" = TransHeader."FSN Document Type"::"Nota Credito" then begin
                TransactionHeaderEx.reset;
                TransactionHeaderEx.SetRange(TransactionHeaderEx."Store No.", TransHeader."Store No.");
                TransactionHeaderEx.SetRange(TransactionHeaderEx."POS Terminal No.", TransHeader."POS Terminal No.");
                TransactionHeaderEx.SetRange(TransactionHeaderEx."Receipt No.", TransHeader."Retrieved from Receipt No.");
                if TransactionHeaderEx.FindFirst() then begin
                    RemissionB := TransactionHeaderEx."FSN Remission No.";
                    TransHeaderTemp.Init;
                    TransHeaderTemp := TransactionHeaderEx;
                    TransHeaderTemp.Insert;
                end;
            end;
        end else begin
            TransHeaderTemp.Init;
            TransHeaderTemp := TransHeader;
            TransHeaderTemp.Insert;
        end;


        if not RemissionB then
            InsertSalesEntry(TransHeader, DocumentlineNo)
        else begin
            RemissionHeaderTmp.RESET;
            RemissionHeaderTmp.DELETEALL;

            SalesEntry.Reset();
            SalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
            SalesEntry.SetRange(SalesEntry."Store No.", TransHeaderTemp."Store No.");
            SalesEntry.SetRange(SalesEntry."POS Terminal No.", TransHeaderTemp."POS Terminal No.");
            SalesEntry.SetRange(SalesEntry."Transaction No.", TransHeaderTemp."Transaction No.");
            if SalesEntry.Find('-') then begin
                repeat
                    IF NOT RemissionHeaderTmp.GET(RemissionHeaderTmp."Document Type"::Remission, SalesEntry."FSN Remission No.") THEN BEGIN
                        IF lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, SalesEntry."FSN Remission No.") THEN BEGIN
                            lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, SalesEntry."FSN Remission No.");
                            _TextRemission := '';
                            _PrintDateRemission := FALSE;
                            IF lCompany.GET(lRemissionHeader."Company No.") THEN BEGIN
                                _PrintDateRemission := lCompany."Print Date In Invoice";
                                _TextRemission := lCompany."Coinsurance Text Add";
                            END;
                            RemissionHeaderTmp.INIT();
                            RemissionHeaderTmp."Document Type" := RemissionHeaderTmp."Document Type"::Remission;
                            RemissionHeaderTmp."No." := SalesEntry."FSN Remission No.";
                            IF _PrintDateRemission THEN
                                RemissionHeaderTmp."External Document No." := COPYSTR(_TextRemission + lRemissionHeader."External Document No." + ' ' + FORMAT(lRemissionHeader."Document Date"), 1, 40)
                            ELSE
                                RemissionHeaderTmp."External Document No." := COPYSTR(_TextRemission + lRemissionHeader."External Document No.", 1, 40);

                            RemissionHeaderTmp.Amount := 0;
                            RemissionHeaderTmp."VAT Amount" := 0;
                            RemissionHeaderTmp."Amount Including VAT" := 0;
                            RemissionHeaderTmp."Disc. Amount" := 0;
                            RemissionHeaderTmp.INSERT();

                            AmountsArr[1] := 0;
                            AmountsArr[2] := 0;
                            AmountsArr[3] := 0;
                            lRemissionLine.RESET;
                            lRemissionLine.SETCURRENTKEY("Document Type", "Document No.", Type);
                            lRemissionLine.SETRANGE(lRemissionLine."Document Type", lRemissionHeader."Document Type");
                            lRemissionLine.SETRANGE(lRemissionLine."Document No.", lRemissionHeader."No.");
                            lRemissionLine.SETFILTER(lRemissionLine.Type, '<>%1', lRemissionLine.Type::Comission);
                            IF lRemissionLine.FIND('-') THEN
                                REPEAT
                                    IF lRemissionLine.Type = lRemissionLine.Type::Item THEN BEGIN
                                        AmountsArr[1] += lRemissionLine.Amount;
                                        AmountsArr[2] += lRemissionLine."VAT Amount";
                                        AmountsArr[3] += lRemissionLine."Amount Including VAT";
                                    END ELSE BEGIN
                                        AmountsArr[1] -= lRemissionLine.Amount;
                                        AmountsArr[2] -= lRemissionLine."VAT Amount";
                                        AmountsArr[3] -= lRemissionLine."Amount Including VAT";
                                    END;
                                UNTIL lRemissionLine.NEXT = 0;
                            RemissionHeaderTmp.Amount -= AmountsArr[1];
                            RemissionHeaderTmp."VAT Amount" -= AmountsArr[2];
                            RemissionHeaderTmp."Amount Including VAT" -= AmountsArr[3];
                            RemissionHeaderTmp.MODIFY;
                            /* RemissionHeaderTmp.Amount += SalesEntry."Net Amount";
                            RemissionHeaderTmp."VAT Amount" += SalesEntry."VAT Amount";
                            RemissionHeaderTmp."Disc. Amount" += SalesEntry."Discount Amount";
                            RemissionHeaderTmp."Amount Including VAT" += SalesEntry."Net Amount" + SalesEntry."VAT Amount";
                            RemissionHeaderTmp.MODIFY; */
                        END ELSE BEGIN
                            RemissionHeaderTmp.INIT();
                            RemissionHeaderTmp."Document Type" := RemissionHeaderTmp."Document Type"::Remission;
                            RemissionHeaderTmp."No." := SalesEntry."FSN Remission No.";
                            RemissionHeaderTmp.Amount := 0;//-lSalesInfoRemission."Net Amount";
                            RemissionHeaderTmp."VAT Amount" := 0;//-lSalesInfoRemission."VAT Amount";
                            RemissionHeaderTmp."Disc. Amount" := 0;//-lSalesInfoRemission."Discount Amount";
                            RemissionHeaderTmp."Amount Including VAT" := 0;//-(lSalesInfoRemission."Net Amount" + lSalesInfoRemission."VAT Amount");
                            RemissionHeaderTmp.INSERT();
                            IF RemissionHeaderTmp.GET(RemissionHeaderTmp."Document Type"::Remission, SalesEntry."FSN Remission No.") THEN BEGIN
                                RemissionHeaderTmp.Amount += SalesEntry."Net Amount";
                                RemissionHeaderTmp."VAT Amount" += SalesEntry."VAT Amount";
                                RemissionHeaderTmp."Disc. Amount" += SalesEntry."Discount Amount";
                                RemissionHeaderTmp."Amount Including VAT" += SalesEntry."Net Amount" + SalesEntry."VAT Amount";
                                RemissionHeaderTmp.MODIFY;
                            END;
                        END;
                    END ELSE BEGIN
                        IF NOT lRemissionHeader.GET(lRemissionHeader."Document Type"::Remission, SalesEntry."FSN Remission No.") THEN BEGIN
                            RemissionHeaderTmp.Amount += SalesEntry."Net Amount";
                            RemissionHeaderTmp."VAT Amount" += SalesEntry."VAT Amount";
                            RemissionHeaderTmp."Disc. Amount" += SalesEntry."Discount Amount";
                            RemissionHeaderTmp."Amount Including VAT" += SalesEntry."Net Amount" + SalesEntry."VAT Amount";
                            RemissionHeaderTmp.MODIFY;
                        END;
                    END;
                until SalesEntry.Next() = 0;

                CLEAR(CompanyInsurer);
                CompanyInsurer.SETRANGE(CompanyInsurer."No.", lRemissionHeader."Company No.");
                CompanyInsurer.SETRANGE(CompanyInsurer."Customer No.", lRemissionHeader."Customer No.");
                IF (CompanyInsurer.FINDFIRST) THEN
                    IF ((CompanyInsurer."Usar Remision" = false) AND (RemissionHeaderTmp.COUNT = 1)) THEN
                        RemissionB := false
                    else
                        RemissionB := true;

                //para imprimir detalle de la remission
                if RemissionB then begin
                    VATAmt := 0;
                    VATGravado := 0;
                    VATExento := 0;
                    RemissionHeaderTmp.Reset();
                    if RemissionHeaderTmp.Find('-') then
                        repeat
                            DetalleDocumento.Init();
                            DetalleDocumento.Quantity := 1;
                            DetalleDocumento.Counter := 300;//remission
                            DetalleDocumento."VAT Amount" := RemissionHeaderTmp."VAT Amount";
                            VATGravado := VATGravado + Round(RemissionHeaderTmp.Amount, 0.01);
                            VATAmt := VATAmt + Round(RemissionHeaderTmp."VAT Amount", 0.01);
                            //VATAmt := VATAmt + RemissionHeaderTmp."VAT Amount";
                            //VATGravado := VATGravado + RemissionHeaderTmp.Amount;
                            DetalleDocumento."Net Amount" := RemissionHeaderTmp.Amount;
                            DetalleDocumento.Price := RemissionHeaderTmp."VAT Amount" + RemissionHeaderTmp.Amount;
                            DetalleDocumento."Posting Exception Key" := DELCHR(DELCHR(RemissionHeaderTmp."External Document No.", '=', '>'), '=', '<');
                            DocumentlineNo += 1;
                            DetalleDocumento."Line No." := DocumentlineNo;
                            DetalleDocumento."Discount Amt. For Printing" := 0;
                            DetalleDocumento.Insert();
                        until RemissionHeaderTmp.Next() = 0;
                end else begin
                    InsertSalesEntry(TransHeader, DocumentlineNo);
                end;
            end;
        end;
        TransIncExpEntry.Reset();
        TransIncExpEntry.SetRange("Store No.", TransHeader."Store No.");
        TransIncExpEntry.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransIncExpEntry.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransIncExpEntry.Find('-') then
            repeat
                if not AcoutIncEcp.Get(TransIncExpEntry."Store No.", TransIncExpEntry."No.") then
                    AcoutIncEcp.Description := 'Cuenta ingreso-gasto';
                DetalleDocumento.Init();
                DetalleDocumento.Quantity := 1;
                DetalleDocumento."VAT Amount" := TransIncExpEntry."VAT Amount";
                DetalleDocumento."Net Amount" := TransIncExpEntry."Net Amount";
                DetalleDocumento."Posting Exception Key" := 'Cuenta: ' + AcoutIncEcp.Description;
                DocumentlineNo += 1;
                DetalleDocumento."Line No." := DocumentlineNo;
                DetalleDocumento."Discount Amt. For Printing" := 0;
                DetalleDocumento.Insert();
            until TransIncExpEntry.Next() = 0;

    end;

    local procedure EncontrarBeneficiario(TransHeaderExt: Record "FSN Transaction Header Ext")
    var
        rTransInfo: Record "LSC Trans. Infocode Entry";
    begin
        Clear(NombreGlobal);
        Clear(BeneficiarioGlobal);
        Clear(TitualarGlobal);
        if TransHeaderGlobal."FSN Customer Name" <> '' then
            CustomerGlobal.Name := TransHeaderGlobal."FSN Customer Name";
        if CustomerGlobal."FSN Request Beneficiary" then begin
            rTransInfo.Reset();
            rTransInfo.SetRange("Transaction No.", TransactionHeaderExt."Transaction No.");
            rTransInfo.SetRange("Store No.", TransactionHeaderExt."Store No.");
            rTransInfo.SetRange("POS Terminal No.", TransactionHeaderExt."POS Terminal No.");
            rTransInfo.SETFILTER(Information, 'BENEFICIARIO*');
            if rTransInfo.FIND('-') THEN begin
                BeneficiarioGlobal := COPYSTR(rTransInfo.Information, 16, 70);
                CustomerGlobal.Name := COPYSTR(rTransInfo.Information, 16, 70)
            end;
            rTransInfo.SetFilter(Information, 'TITULAR*');
            if rTransInfo.Find('-') then
                TitualarGlobal := COPYSTR(rTransInfo.Information, 16, 70);
        end;

        NombreGlobal := CustomerGlobal.Name;
    end;

    procedure InsertSalesEntry(TransHeader: Record "LSC Transaction Header"; var DocumentlineNo: Integer)
    var
        SalesEntry: Record "LSC Trans. Sales Entry";
        TransInfoEntry: Record "LSC Trans. Infocode Entry";
    begin
        SalesEntry.Reset();
        SalesEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        SalesEntry.SetRange(SalesEntry."Store No.", TransHeader."Store No.");
        SalesEntry.SetRange(SalesEntry."POS Terminal No.", TransHeader."POS Terminal No.");
        SalesEntry.SetRange(SalesEntry."Transaction No.", TransHeader."Transaction No.");
        if SalesEntry.Find('-') then
            repeat
                DetalleDocumento.Init();
                DetalleDocumento.TransferFields(SalesEntry);
                if SalesEntry.Quantity = 0 then
                    DetalleDocumento.Quantity := 1;//Item <> 0
                DocumentlineNo += 1;
                DetalleDocumento."Line No." := DocumentlineNo;
                DetalleDocumento.Counter := 0;//Item
                DetalleDocumento."Discount Amt. For Printing" := 0;
                DetalleDocumento.Insert();

                TransInfoEntry.RESET;
                TransInfoEntry.SETRANGE(TransInfoEntry."Store No.", SalesEntry."Store No.");
                TransInfoEntry.SETRANGE(TransInfoEntry."POS Terminal No.", SalesEntry."POS Terminal No.");
                TransInfoEntry.SETRANGE(TransInfoEntry."Transaction No.", SalesEntry."Transaction No.");
                TransInfoEntry.SETRANGE(TransInfoEntry.Infocode, 'NRECETA');//28981
                TransInfoEntry.SETRANGE(TransInfoEntry."Line No.", SalesEntry."Line No.");
                IF TransInfoEntry.FINDFIRST then begin
                    DetalleDocumento.Init();
                    DetalleDocumento.Price := 0;
                    DetalleDocumento.Quantity := 0; //not item
                    DetalleDocumento.Counter := 100; //Infocode
                    DetalleDocumento."Posting Exception Key" := CopyStr(TransInfoEntry.Infocode + ': ' + TransInfoEntry.Information, 1, 50);
                    DocumentlineNo += 1;
                    DetalleDocumento."Line No." := DocumentlineNo;
                    DetalleDocumento."Discount Amt. For Printing" := 0;
                    DetalleDocumento.Insert();
                end;
            until SalesEntry.Next() = 0;
    end;

    local procedure GetQuantity(pItem: Code[20]; pUnit: Code[10]; pQty: Decimal; pCounter: Decimal): Decimal
    var
        ItemUnitMeasure: Record "Item Unit of Measure";
    begin
        if pCounter <> 0 then
            Exit(pQty)
        else begin
            Clear(ItemUnitMeasure);
            if not ItemUnitMeasure.Get(pItem, pUnit) then;
            if ItemUnitMeasure."Qty. per Unit of Measure" = 0 then
                ItemUnitMeasure."Qty. per Unit of Measure" := 1;
            Exit(Abs(Round(pQty / ItemUnitMeasure."Qty. per Unit of Measure", 0.1)));

        end;
    end;
}