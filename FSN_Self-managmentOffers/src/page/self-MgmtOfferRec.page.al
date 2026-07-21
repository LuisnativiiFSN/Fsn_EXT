page 50084 "FSN Self-Mgmt Offers Record"
{
    Caption = 'Ofertas FSN por referencia';
    //SourceTable = "FSN Self-Mgmt Offers";
    SourceTable = "FSN Inventory Internal Log";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            /* group("data")
            {
                repeater(group)
                {
                    field("Offer Type"; Rec."Offer Type")
                    {
                        ApplicationArea = All;
                        Caption = 'Offer Type';
                    }
                    field("bank name"; Rec."bank name")
                    {
                        ApplicationArea = All;
                        Caption = 'bank name';
                    }
                    field(Store; Rec.Store)
                    {
                        ApplicationArea = All;
                        Caption = 'Store';
                    }
                    field("start date"; Rec."start date")
                    {
                        ApplicationArea = All;
                        Caption = 'start date';
                    }
                    field("end date"; Rec."end date")
                    {
                        ApplicationArea = All;
                        Caption = 'end date';
                    }
                    field(Type; Rec.Type)
                    {
                        ApplicationArea = All;
                        Caption = 'Type';
                    }
                    field("Item No."; Rec."Item No.")
                    {
                        ApplicationArea = All;
                        Caption = 'Item No';
                    }
                    field("Item Description"; Rec."Item Description")
                    {
                        ApplicationArea = All;
                        Caption = 'Item Description';
                    }
                    field("Unit of Measure"; Rec."Unit of Measure")
                    {
                        ApplicationArea = All;
                        Caption = 'Unit of Measure';
                    }
                    field("% Discount"; Rec."% Discount")
                    {
                        ApplicationArea = All;
                        Caption = '% Discount';
                    }
                    field(Price; Rec.Price)
                    {
                        ApplicationArea = All;
                        Caption = 'Price';
                    }
                    field("discount Group"; Rec."discount Group")
                    {
                        ApplicationArea = All;
                        Caption = 'discount Group';
                    }
                    Field("Sell Out"; Rec."Sell Out")
                    {
                        ApplicationArea = All;
                        Caption = 'Sell Out';
                    }
                    field("Sell Out Value"; Rec."Sell Out Value")
                    {
                        ApplicationArea = All;
                        Caption = 'Sell Out Value';
                    }
                    field("Web Category Type"; Rec."Web Category Type")
                    {
                        ApplicationArea = All;
                        Caption = 'Web Category Type';
                    }
                    field("Web Category ame"; Rec."Web Category name")
                    {
                        ApplicationArea = All;
                        Caption = 'Web Category name';
                    }
                    field("Web category Start Date"; Rec."Web category Start Date")
                    {
                        ApplicationArea = All;
                        Caption = 'Web category Start Date';
                    }
                    field("Web category End Date"; Rec."Web category End Date")
                    {
                        ApplicationArea = All;
                        Caption = 'Web category End Date';
                    }
                }*/
            repeater(group)
            {
                field("Item No."; Rec."No.")
                {
                    ApplicationArea = All;
                    Caption = 'Item No';
                }
                field("Item Description"; getItemDescription(Rec."No."))
                {
                    ApplicationArea = All;
                    Caption = 'Item Description';
                }
                field("Item No. Reference"; Rec."Item No. Ref.")
                {
                    ApplicationArea = All;
                    Caption = 'Item No. Reference';
                }
                field("Item Description Reference"; getItemDescription(Rec."Item No. Ref."))
                {
                    ApplicationArea = All;
                    Caption = 'Item Description Reference';
                }
                field("status"; Rec."Receipt No. Request")
                {
                    ApplicationArea = All;
                    Caption = 'status';
                }
                field("Retail"; getDiscount(Rec."Item No. Ref.", 'RETAIL'))
                {
                    ApplicationArea = All;
                    Caption = 'RETAIL';
                }
                field("VIP"; getDiscount(Rec."Item No. Ref.", 'VIP'))
                {
                    ApplicationArea = All;
                    Caption = 'VIP';
                }
                field("FSN"; getDiscount(Rec."Item No. Ref.", 'FASANI'))
                {
                    ApplicationArea = All;
                    Caption = 'FSN';
                }
                field("VAGRI"; getDiscount(Rec."Item No. Ref.", 'VAGRI'))
                {
                    ApplicationArea = All;
                    Caption = 'VAGRI';
                }
            }
        }
    }
    actions
    {
        area("navigation")
        {
            action("Load Items")
            {
                ApplicationArea = All;
                Caption = 'Cargar descuentos', comment = '="YourLanguageCaption"';
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                begin
                    loadDiscounts();
                end;
            }
        }
    }
    local procedure getItemDescription(itemNo: Code[20]): Text[100]
    var
        item: Record "Item";
    begin
        if not item.Get(itemNo) then
            exit('');

        exit(item.Description);
    end;

    local procedure getDiscount(ItemNo: Code[20]; reference: Code[20]): Decimal
    var
        periodicDiscount: Record "LSC Periodic Discount Line";
        NoOffer: Code[20];
        prefix: label 'PRECIO_%1';
    begin
        NoOffer := StrSubstNo(prefix, reference);

        periodicDiscount.SetRange("Offer No.", NoOffer);
        periodicDiscount.SetRange("No.", ItemNo);
        if not periodicDiscount.FindSet() then
            exit(0.0);

        exit(periodicDiscount."Deal Price/Disc. %");
    end;

    local procedure getLastLine(offerDiscount_old: Code[20]): Integer
    var
        periodicDiscount: Record "LSC Periodic Discount Line";
    begin
        periodicDiscount.SetCurrentKey("Offer No.", "Line No.");
        periodicDiscount.SetRange("Offer No.", offerDiscount_old);
        if periodicDiscount.FindLast() then
            exit(periodicDiscount."Line No." + 10);
    end;

    local procedure loadDiscounts()
    var
        periodicDiscLine_tmp: Record "LSC Periodic Discount Line";
        periodicDiscLine_1, periodicDiscLine_2 : Record "LSC Periodic Discount Line";
        periodicDisc: Record "LSC Periodic Discount";
        saleLinesDiscount_1, saleLinesDiscount_2 : Record "Sales Line Discount";
        saleLinesDiscount_tmp: Record "Sales Line Discount" temporary;
        itemUnitOfMeasure: Record "Item Unit of Measure";
        itemSpecialGroup_1, itemSpecialGroup_2 : Record "LSC Item/Special Group Link";
        CustomerDiscountGroup: Record "Customer Discount Group";
        lastLine, i : Integer;
        offerDiscount_old: array[6] of Code[20];
        enableOffer_old: array[6] of Boolean;
        offerDiscount: List Of [Code[20]];
        enableOffer: List Of [Boolean];
        prefix: label 'PRECIO_';
        TEXT000: Label 'Esta seguro de cargar los nuevos descuentos de productos?';
        TEXT001: Label 'No hay items para cargar';
        TEXT002: Label 'Los descuentos se cargaron correctamente';
    begin
        if not Dialog.Confirm(TEXT000, true) then
            exit;

        if not Rec.Find('-') then
            Error(TEXT001);
        repeat
            itemSpecialGroup_2.Reset();
            itemSpecialGroup_2.SetRange("Item No.", Rec."No.");
            itemSpecialGroup_2.DeleteAll(true);

            saleLinesDiscount_2.Reset();
            saleLinesDiscount_2.SetRange(saleLinesDiscount_2."Code", Rec."No.");
            saleLinesDiscount_2.DeleteAll(true);

            itemSpecialGroup_1.Reset();
            CLEAR(itemSpecialGroup_1);
            itemSpecialGroup_1.SetFilter(itemSpecialGroup_1."Item No.", Rec."Item No. Ref.");

            saleLinesDiscount_1.Reset();
            CLEAR(saleLinesDiscount_1);
            saleLinesDiscount_1.SetRange(saleLinesDiscount_1.Code, Rec."Item No. Ref.");

            if itemSpecialGroup_1.Find('-') then
                repeat
                    itemSpecialGroup_2.INIT;
                    itemSpecialGroup_2."Item No." := Rec."No.";
                    itemSpecialGroup_2."Special Group Code" := itemSpecialGroup_1."Special Group Code";
                    itemSpecialGroup_2.INSERT(TRUE);
                UNTIL itemSpecialGroup_1.NEXT = 0;

            IF saleLinesDiscount_1.FIND('-') THEN
                REPEAT
                    if saleLinesDiscount_1."Sales Code" <> '' then begin
                        //IF CustomerDiscountGroup.GET(saleLinesDiscount_1."Sales Code") AND CustomerDiscountGroup."FSN Take To Load New Item" THEN;

                        IF (saleLinesDiscount_tmp.Code <> saleLinesDiscount_1.Code) OR
                    ((saleLinesDiscount_tmp.Code = saleLinesDiscount_1.Code) AND (saleLinesDiscount_tmp."Sales Code" <> saleLinesDiscount_1."Sales Code")) THEN BEGIN
                            saleLinesDiscount_tmp := saleLinesDiscount_1;
                            itemUnitOfMeasure.RESET;
                            CLEAR(itemUnitOfMeasure);
                            itemUnitOfMeasure.SETRANGE(itemUnitOfMeasure."Item No.", Rec."No.");
                            IF (itemUnitOfMeasure.FIND('-')) THEN
                                REPEAT
                                    saleLinesDiscount_2.INIT();
                                    saleLinesDiscount_2 := saleLinesDiscount_1;
                                    saleLinesDiscount_2.Code := Rec."No.";
                                    saleLinesDiscount_2."Unit of Measure Code" := itemUnitOfMeasure.Code;
                                    saleLinesDiscount_2.INSERT(TRUE);
                                UNTIL itemUnitOfMeasure.NEXT = 0;
                        END;
                    end;
                UNTIL saleLinesDiscount_1.NEXT = 0;
        until Rec.Next() = 0;

        //ACTUALIZACION DE OFERTA GRUPO DESCUENTOS
        Rec.RESET;
        Rec.FIND('-');
        //todo: refactor to dynamics array
        periodicDisc.Reset();
        //periodicDisc.SetFilter("No.", '%1*', prefix);
        if periodicDisc.Find('-') then
            repeat
                if Format(CopyStr(periodicDisc."No.", 1, 7)) = prefix then begin
                    offerDiscount.Add(periodicDisc."No.");
                    enableOffer.Add(periodicDisc.Status = periodicDisc.Status::Enabled);
                    periodicDisc.Status := periodicDisc.Status::Disabled;
                    periodicDisc.Modify(true);
                end;
            until periodicDisc.Next() = 0;

        /* offerDiscount_old[1] := 'PRECIO_RETAIL';
        offerDiscount_old[2] := 'PRECIO_VIP';
        offerDiscount_old[3] := 'PRECIO_FASANI';
        offerDiscount_old[4] := 'PRECIO_VAGRI';
        offerDiscount_old[5] := 'PRECIO_ADF';
        offerDiscount_old[6] := 'PRECIO_HUGO';
        FOR i := 1 TO ARRAYLEN(offerDiscount_old) DO
            IF periodicDisc.GET(offerDiscount_old[i]) THEN BEGIN
                CLEAR(enableOffer_old[i]);
                IF periodicDisc.Status = periodicDisc.Status::Enabled THEN BEGIN
                    periodicDisc.Status := periodicDisc.Status::Disabled;
                    periodicDisc.MODIFY(TRUE);
                    enableOffer_old[i] := TRUE;
                END;
            END; */

        REPEAT
            FOR i := 1 TO offerDiscount.Count() DO BEGIN
                LastLine := GetLastLine(offerDiscount.Get(i));
                periodicDiscLine_1.RESET;
                periodicDiscLine_1.SETCURRENTKEY("Offer No.", "Line No.");
                periodicDiscLine_1.SETRANGE(periodicDiscLine_1."Offer No.", offerDiscount.Get(i));
                periodicDiscLine_1.SETRANGE(periodicDiscLine_1."No.", Rec."Item No. Ref.");
                IF periodicDiscLine_1.FINDFIRST THEN BEGIN
                    periodicDiscLine_2.RESET;
                    periodicDiscLine_2.SETCURRENTKEY("Offer No.", "Line No.");
                    periodicDiscLine_2.SETRANGE("Offer No.", offerDiscount.Get(i));
                    periodicDiscLine_2.SETRANGE(periodicDiscLine_2."No.", Rec."No.");
                    IF periodicDiscLine_2.FIND('-') THEN BEGIN
                        REPEAT
                            periodicDiscLine_2.VALIDATE(periodicDiscLine_2."Deal Price/Disc. %", periodicDiscLine_1."Deal Price/Disc. %");
                            periodicDiscLine_2.MODIFY(TRUE);
                        UNTIL periodicDiscLine_2.NEXT = 0;
                        //periodicDiscLine_tmp.MODIFYALL(periodicDiscLine_tmp."Deal Price/Disc. %",PeriodicDiscountL."Deal Price/Disc. %",TRUE);
                    END ELSE BEGIN
                        periodicDiscLine_tmp.INIT;
                        periodicDiscLine_tmp."Offer No." := offerDiscount.Get(i);
                        periodicDiscLine_tmp."Line No." := LastLine;
                        periodicDiscLine_tmp.VALIDATE("No.", Rec."No.");
                        periodicDiscLine_tmp.VALIDATE("Deal Price/Disc. %", periodicDiscLine_1."Deal Price/Disc. %");
                        periodicDiscLine_tmp.INSERT(TRUE);
                    END;
                END ELSE BEGIN
                    periodicDiscLine_tmp.RESET;
                    periodicDiscLine_tmp.SETCURRENTKEY("Offer No.", "Line No.");
                    periodicDiscLine_tmp.SETRANGE("Offer No.", offerDiscount.Get(i));
                    periodicDiscLine_tmp.SETRANGE(periodicDiscLine_tmp."No.", Rec."No.");
                    IF periodicDiscLine_tmp.FINDFIRST THEN BEGIN
                        REPEAT
                            periodicDiscLine_tmp.VALIDATE(periodicDiscLine_tmp."Deal Price/Disc. %", 0.0);
                            periodicDiscLine_tmp.MODIFY(TRUE);
                        UNTIL periodicDiscLine_tmp.NEXT = 0;
                        //periodicDiscLine_tmp.MODIFYALL(periodicDiscLine_tmp."Deal Price/Disc. %", 0.0,TRUE);
                    END;
                END;
            END;
            Rec."Receipt No. Request" := 'OK';
            Rec.MODIFY();
        UNTIL Rec.NEXT = 0;

        FOR i := 1 TO offerDiscount.Count() DO
            IF enableOffer.Get(i) THEN BEGIN
                IF periodicDisc.GET(offerDiscount.Get(i)) THEN BEGIN
                    periodicDisc.MODIFY(TRUE);
                    periodicDisc.Status := periodicDisc.Status::Enabled;
                    periodicDisc.MODIFY(FALSE);
                END;
            END;

        Message(TEXT002);
    end;
}