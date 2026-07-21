table 50019 "FSN External Purch. Sub Line"
{
    //WVILLALTA 10.21             - C/AL to AL

    Caption = 'External Purch. Sub Line';

    fields
    {
        field(10; "No."; Code[20])
        {
            Caption = 'No.';
            Description = 'Key';
            Editable = true;
        }
        field(20; "Line No."; Integer)
        {
            Caption = 'Line No.';
            Description = 'Key';
            Editable = true;
        }
        field(21; "Line No. Detail"; Integer)
        {
        }
        field(30; "Starting Date"; Date)
        {
            Caption = 'Starting Date';
        }
        field(35; "Ending Date"; Date)
        {
        }
        field(36; "Ending Time"; DateTime)
        {
        }
        field(55; "External Document No."; Code[35])
        {
            Description = 'Key';
        }
        field(56; "Lot No."; Code[20])
        {
            Description = 'Key';
        }
        field(57; "Expiration Date"; Date)
        {
        }
        field(60; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            Editable = true;
            TableRelation = Item;
        }
        field(65; "Barcode No."; Code[20])
        {
        }
        field(70; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(80; "Qty. to Ship"; Decimal)
        {
            Caption = 'Qty. to Ship';
            DecimalPlaces = 0 : 5;
            MinValue = 0;

            trigger OnValidate()
            var
                Confirmed: Boolean;
            begin
            end;
        }
        field(86; "Unit of Measure Code"; Code[10])
        {
        }
        field(87; "Status Sub. Line"; Option)
        {
            OptionCaption = 'New,Received,ReceiptCreated,ErrorValidation,CloseErasePurch,PurchNotExists,Canceled';
            OptionMembers = New,Received,ReceiptCreated,ErrorValidation,CloseErasePurch,PurchNotExists,Canceled;

            trigger OnValidate()
            begin
                IF ExternalPurchLine.GET("No.", "Line No.") THEN BEGIN
                    ExternalPurchLine."Status NAV" := "Status Sub. Line";
                    IF ("Status Sub. Line" IN ["Status Sub. Line"::Received, "Status Sub. Line"::ReceiptCreated]) THEN BEGIN
                        ExternalPurchLine."Qty. to Receive" += "Qty. to Ship";
                        ExternalPurchLine."Ending Date" := CURRENTDATETIME;
                        ExternalPurchLine.TransferComplete := TRUE;
                        ExternalPurchLine.Received := TRUE;
                        ExternalPurchLine."Description Error" := '';
                    END;
                    ExternalPurchLine.MODIFY;
                END ELSE
                    IF xRec."Status Sub. Line" = Rec."Status Sub. Line"::Canceled THEN BEGIN
                        ExternalPurchLine.RESET;
                        ExternalPurchLine.SETRANGE(ExternalPurchLine."No.", "No.");
                        IF ExternalPurchLine.FIND('-') THEN BEGIN
                            ExternalPurchLine.MODIFYALL(ExternalPurchLine."Status NAV", "Status Sub. Line");
                            ExternalPurchLine.MODIFYALL(ExternalPurchLine.Received, TRUE);
                            ExternalPurchLine.MODIFYALL(ExternalPurchLine."Description Error", gText001);
                        END;
                    END;
            end;
        }
        field(90; "Retail Receiving No."; Code[20])
        {
            Caption = 'Retail Receiving No.';
        }
        field(100; "Eraser by User"; Boolean)
        {
        }
        field(110; "Signature Validation"; Text[100])
        {
            Caption = 'Signature Validation';
        }
        field(120; "DTE AuthNumber"; Code[100])
        {
            Caption = 'DTE AuthNumber';
        }
        field(130; "Unit Cost"; Decimal)
        {
            Caption = 'Unit Cost';
        }
    }

    keys
    {
        key(Key1; "No.", "Line No.", "External Document No.", "Lot No.")
        {
            Clustered = true;
        }
        key(Key2; "Status Sub. Line")
        {
        }
        key(Key3; "No.", "External Document No.")
        {
        }
        key(Key4; "Retail Receiving No.", "No.", "Eraser by User")
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnModify()
    begin
        VALIDATE("Status Sub. Line");
    end;

    var
        ExternalPurchLine: Record "FSN External Purch. Line";
        gText001: Label 'Canceled';
}

