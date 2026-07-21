table 50043 "FSN Replen. Jrnl. Add"
{

    fields
    {
        field(10; "Item No."; Code[20])
        {

            trigger OnValidate()
            begin
                Description := '';
                IF Item.GET("Item No.") THEN
                    Description := Item.Description;
            end;
        }
        field(20; "Location Code"; Code[10])
        {
        }
        field(30; Description; Text[100])
        {
        }
        field(40; "Replen. Template Code"; Code[10])
        {
            TableRelation = "LSC Replen. Template".Code;
        }
        field(50; Quantity; Decimal)
        {

            trigger OnValidate()
            begin
                IF Quantity > 0 THEN BEGIN

                    ReplenItemStoreRec.SETCURRENTKEY("Item No.", "Variant Code", "Location Code", "Active From Date");
                    ReplenItemStoreRec.SETRANGE(ReplenItemStoreRec."Item No.", "Item No.");
                    ReplenItemStoreRec.SETRANGE(ReplenItemStoreRec."Location Code", "Location Code");
                    IF ReplenItemStoreRec.FIND('-') THEN
                        IF ReplenItemStoreRec."FSN Purch. Multiple" > 0 THEN BEGIN

                            Qty := Quantity;
                            QtyRounded := ROUND(Quantity, ReplenItemStoreRec."FSN Purch. Multiple", '>');
                            QtyDiff := Qty - QtyRounded;
                            IF ((QtyDiff / ReplenItemStoreRec."FSN Purch. Multiple") * 100) >= 0.49 THEN
                                Quantity := QtyRounded + ReplenItemStoreRec."FSN Purch. Multiple"
                            ELSE
                                Quantity := QtyRounded;

                        END;
                END;
            end;
        }
        field(60; "Date Filter"; Date)
        {
        }
        field(70; "Message Error"; Text[50])
        {
        }
    }

    keys
    {
        key(Key1; "Item No.", "Location Code", "Replen. Template Code")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }

    trigger OnInsert()
    begin
        "Message Error" := '';
        IF "Location Code" = '' THEN
            "Message Error" := FIELDNAME("Location Code");
        IF "Item No." = '' THEN
            "Message Error" := FIELDNAME("Item No.");
        IF "Replen. Template Code" = '' THEN
            "Message Error" := FIELDNAME("Replen. Template Code");
    end;

    var
        Item: Record Item;
        ReplenItemStoreRec: Record "LSC Replen. Item Store Rec";
        QtyRounded: Decimal;
        Qty: Decimal;
        QtyDiff: Decimal;
        Txt000: Label '%1 cant be empty';
        Multiple: Decimal;
}

