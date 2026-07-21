page 50105 "ZY HyperLink"
{
    Caption = 'Búsqueda de Productos';
    AboutText = 'Página de búsqueda de productos';
    Editable = true;
    PageType = Card;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            // Grupo para el campo URL (puedes ponerlo arriba o en un FastTab
            group(GroupName)
            {
                ShowCaption = false;
                usercontrol(Response; "SPLN Demo")
                {
                    ApplicationArea = All;

                    trigger ControlAddInReady(callbackUrl: Text)
                    begin
                        CurrPage.Response.Navigate(URL);
                    end;

                    trigger ProductosRecibidos(Jobject: JsonObject)
                    begin
                        if ValidateGiftCard(Jobject) then
                            exit;
                        CurrPage.TransLine.PAGE.GlobalPosTransa(GloBalPos);
                        CurrPage.TransLine.PAGE.RecibirProductos(Jobject);
                        CurrPage.TransLine.PAGE.Update(false);
                        CurrPage.Update(false);
                    end;
                }
                group(factboxes)
                {
                    ShowCaption = false;
                    part(TransLine; "PREFACTURA CC")
                    {
                        ApplicationArea = All;
                        Editable = true;
                    }
                }
            }

        }
    }
    actions
    {
        area(Processing)
        {
            action(InsertM)
            {
                ApplicationArea = All;
                Caption = 'Insertar/Modificar';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    myInt: Integer;
                    item: Record Item;
                    PosTransLine: Record "LSC POS Trans. Line" temporary;
                begin
                    CurrPage.TransLine.PAGE.GetCurrentRecord(PosTransLine);
                    InsertItemsLines(PosTransLine);
                    CurrPage.TransLine.PAGE.Update(false);
                    CurrPage.Close();
                end;
            }
            action(Inventario)
            {
                ApplicationArea = All;
                Caption = 'Salas Sugeridas';
                Promoted = true;
                PromotedCategory = Process;
                Image = ItemSubstitution;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    myInt: Integer;
                    Contact: Record "LSC Delivery Contact Address";
                    DelOrder: Record "LSC Delivery Order";
                    PosTransLine: Record "LSC POS Trans. Line" temporary;
                    ContactTMP: Record "LSC Delivery Contact Address" temporary;
                    OrderTMP: Record "LSC POS Trans. Line" temporary;
                    POSTransLTMP: Record "LSC POS Trans. Line" temporary;
                    StoreTMP: Record "LSC Store" temporary;
                    DeliveryStreet_l: Record "LSC Delivery Street";
                    DeliveryStreetTMP: Record "LSC Delivery Street" temporary;
                begin
                    PosTransLine.DeleteAll();
                    CurrPage.TransLine.PAGE.RecordInv(PosTransLine);
                    if DelOrder.GET(GloBalPos."Receipt No.") then begin
                        PosTransLine.RESET;
                        PosTransLine.SETRANGE("Receipt No.", DelOrder."Order No.");
                        PosTransLine.SETRANGE("Entry Type", PosTransLine."Entry Type"::Item);
                        PosTransLine.SetRange("Store No.", DelOrder."Restaurant No.");
                        PosTransLine.SetRange("Entry Status", PosTransLine."Entry Status"::" ");
                        if PosTransLine.Find('-') then
                            repeat
                                OrderTMP.Init();
                                OrderTMP := PosTransLine;
                                OrderTMP.Quantity := PosTransLine."Card Entry No.";
                                OrderTMP.Insert();
                                POSTransLTMP.INIT;
                                POSTransLTMP := PosTransLine;
                                POSTransLTMP.Quantity := PosTransLine."Card Entry No.";
                                POSTransLTMP.Insert();
                            until PosTransLine.NEXT = 0;
                        Contact.reset;
                        Contact.SETRANGE("Phone No.", DelOrder."Phone No.");
                        Contact.SETRANGE("Address Type", DelOrder."Order Type Option" - 1);
                        if Contact.FindFirst() then begin
                            ContactTMP.INIT;
                            ContactTMP := Contact;
                            ContactTMP.Insert();
                        end;
                        wsprefac.GetGlobalCommand('FSN_ECOMM_CHECK_DELSTORE_X');
                        wsprefac.XCheckOrderDelivery(true, POSTransLine."Receipt No.", ContactTMP, OrderTMP, POSTransLTMP, DelOrder);
                    end;
                end;
            }
        }
    }
    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        LineInsert := false;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        myInt: Integer;
        PosTransLine: Record "LSC POS Trans. Line" temporary;
    begin
        if LineInsert then
            exit(true)
        else begin
            CurrPage.TransLine.PAGE.GetCurrentRecord(PosTransLine);
            //InsertItemsLines(PosTransLine);//28981
            CurrPage.TransLine.PAGE.Update(false);
            exit(true);
        end;
    end;

    trigger OnClosePage()
    var
        EPosCtrl: Codeunit "LSC POS Control Interface";
        terminal: Record "LSC POS Terminal";
        POSTTransacC: Codeunit "LSC POS Transaction";
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        HospiPOSStartup: Codeunit "LSC Hospitality POS Startup";
        Postransaction: Record "LSC POS Transaction";
        DeliveryOrder: Record "LSC Delivery Order";
    begin
        if not Giftcard then
            HospiPOSStartup.DirectEdit(true);
    end;


    var
        URL: Text;
        LineInsert: Boolean;
        GloBalPos: Record "LSC POS Transaction";
        wsprefac: codeunit "calculation process";
        Giftcard: Boolean;

    procedure InsertItemsLines(var PosTransLine: Record "LSC POS Trans. Line" temporary)
    var
        Linea, Diferencias : Integer;
        TransLine, InsertLine, CompresLine, MixMLine : Record "LSC POS Trans. Line";
        VATS: Record "VAT Posting Setup";
        DT: Record "LSC POS Trans. Per. Disc. Type";
        OfferPosCalc: Record "LSC Offer Pos Calculation";
        PosPriceUtil: Codeunit "LSC POS Price Utility";
        PosFunc: Codeunit "LSC POS Functions";
    begin
        TransLine.Reset();
        TransLine.SetRange("Receipt No.", PosTransLine."Receipt No.");
        TransLine.SetRange("POS Terminal No.", PosTransLine."POS Terminal No.");
        TransLine.SetRange("Store No.", PosTransLine."Store No.");
        TransLine.SetRange("Entry Status", TransLine."Entry Status"::" ");
        if TransLine.FindLast() then
            Linea := TransLine."Line No.";

        PosTransLine.SetRange("Entry Type", PosTransLine."Entry Type"::Item);
        if PosTransLine.Find('-') then
            repeat
                CompresLine.Reset();
                CompresLine.SetRange("Receipt No.", PosTransLine."Receipt No.");
                CompresLine.SetRange("POS Terminal No.", PosTransLine."POS Terminal No.");
                CompresLine.SetRange("Store No.", PosTransLine."Store No.");
                CompresLine.SetRange(Number, PosTransLine.Number);
                CompresLine.SetRange("Unit of Measure", PosTransLine."Unit of Measure");
                CompresLine.SetRange("Entry Type", PosTransLine."Entry Type");
                CompresLine.SetRange("Entry Status", CompresLine."Entry Status"::" ");
                if CompresLine.FindFirst() then begin
                    if CompresLine.Quantity <> PosTransLine."Card Entry No." then begin
                        MixMLine.Reset();
                        MixMLine.SetRange("Receipt No.", PosTransLine."Receipt No.");
                        MixMLine.SetRange("POS Terminal No.", PosTransLine."POS Terminal No.");
                        MixMLine.SetRange("Store No.", PosTransLine."Store No.");
                        MixMLine.SetRange(Number, PosTransLine.Number);
                        MixMLine.SetRange("Unit of Measure", PosTransLine."Unit of Measure");
                        MixMLine.SetRange("Entry Status", MixMLine."Entry Status"::" ");
                        MixMLine.CalcSums(Quantity);
                        Diferencias := CompresLine.Quantity - MixMLine.Quantity;
                        CompresLine.Validate(Quantity, PosTransLine."Card Entry No." + Diferencias);
                        CompresLine.Modify(true);
                    end;
                end else begin
                    if GloBalPos.get(PosTransLine."Receipt No.") then;
                    Linea += 10000;
                    InsertLine.Init();
                    InsertLine."Receipt No." := PosTransLine."Receipt No.";
                    InsertLine."POS Terminal No." := PosTransLine."POS Terminal No.";
                    InsertLine."Store No." := PosTransLine."Store No.";
                    InsertLine."Line No." := Linea;
                    InsertLine.VALIDATE("Entry Type", PosTransLine."Entry Type");
                    InsertLine."Parent Line" := InsertLine."Line No.";
                    InsertLine.Validate("Unit of Measure", PosTransLine."Unit of Measure");
                    InsertLine.Validate(Number, PosTransLine.Number);
                    InsertLine.Validate(Quantity, 0);
                    InsertLine."Sales Type" := GloBalPos."Sales Type";
                    InsertLine."Sales Staff" := GloBalPos."Sales Staff";
                    InsertLine."Created by Staff ID" := GloBalPos."Staff ID";
                    InsertLine."Entry Status" := 0;
                    InsertLine."Discount %" := 0;
                    InsertLine."Discount Amount" := 0;
                    InsertLine."Disc. Info Line No." := 0;
                    InsertLine."Discount Triggered" := false;
                    InsertLine."Quantity Discounted" := 0;
                    PosPriceUtil.InsertTransDiscPercent(InsertLine, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                    InsertLine."Promotion No." := '';
                    InsertLine."Mix & Match Line No." := 0;
                    PosPriceUtil.InsertTransDiscAmount(InsertLine, 0, DT.DiscType::"Periodic Disc.".AsInteger(), '');
                    Clear(OfferPosCalc);
                    OfferPosCalc.SetRange("Receipt No.", InsertLine."Receipt No.");
                    OfferPosCalc.SetRange("Trans. Line No.", InsertLine."Line No.");
                    OfferPosCalc.DeleteAll;
                    PosFunc.ClearPosTransLineOffers(InsertLine);
                    PosPriceUtil.CalcPrice(InsertLine, true);
                    if InsertLine.Insert(true) then;
                    InsertLine.Validate(Quantity, PosTransLine."Card Entry No.");
                    if InsertLine.Modify(true) then;
                end;
            until PosTransLine.Next() = 0;
        LineInsert := true;
        PosTransLine.DeleteAll();
    end;

    procedure InsertRecordLine(PosTransLine: Record "LSC POS Trans. Line")
    var

    begin
        CurrPage.TransLine.PAGE.InsertRecordLine(PosTransLine);
    end;

    procedure SetRecordP(PosTransaction: Record "LSC POS Transaction")
    begin
        GloBalPos := PosTransaction;
    end;

    procedure SetURL(NavigateToURL: Text)
    begin
        URL := NavigateToURL;
    end;

    procedure ValidateGiftCard(JsonOb: JsonObject): Boolean
    var
        RunPro, i : Integer;
        jToken, token : JsonToken;
        array: JsonArray;
        producto: JsonObject;
        Barc: Record "LSC Barcodes";
        POSTransCodeunit: Codeunit "LSC POS Transaction";
    begin
        if JsonOb.Get('products', jToken) then // Seleccionar el arreglo "Arreglo
            if jToken.IsArray then   // Verificar que el token es un arreglo y convertirlo
                array := jToken.AsArray();

        // Recorre cada elemento del array recibido
        for i := 0 to array.Count() - 1 do begin
            if array.Get(i, token) and token.IsObject() then begin
                RunPro += 1;
                producto := token.AsObject();
                // Extrae los valores del JSON
                if producto.Get('No_', jToken) then
                    if not jToken.AsValue().IsNull then
                        if jToken.AsValue().AsText() in ['A009557', 'A101680', 'A3582', 'B0000574'] then begin
                            Barc.Reset();
                            Barc.SetRange("Item No.", jToken.AsValue().AsText());
                            if Barc.FindFirst() then begin
                                POSTransCodeunit.PluKeyPressed(Barc."Barcode No.");
                                LineInsert := true;
                                Giftcard := true;
                                CurrPage.Close();
                                exit(true);
                            end;
                        end;
            end;
        end;
    end;
}
