table 50017 "FSN External Purch. Line"
{
    //WVILLALTA 10.21             - C/AL to AL

    Caption = 'External Purch. Line';

    fields
    {
        field(10; "No."; Code[20])
        {
            Caption = 'No.';
            Editable = false;
        }
        field(20; "Line No."; Integer)
        {
            Caption = 'Line No.';
            Editable = false;
        }
        field(30; "Starting Date"; DateTime)
        {
            Caption = 'Starting Date';
        }
        field(35; "Ending Date"; DateTime)
        {
        }
        field(40; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
            Editable = false;
            TableRelation = Location;
        }
        field(50; "Source No."; Code[20])
        {
            Caption = 'Source No.';
            Editable = false;
        }
        field(52; "Vendor No."; Code[20])
        {
        }
        field(54; "Vendor Name"; Text[50])
        {
        }
        field(56; "Vendor Invoice No."; Code[50])
        {
        }
        field(60; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            Editable = false;
            TableRelation = Item;
        }
        field(65; "Barcode No."; Code[22])
        {
        }
        field(70; Description; Text[50])
        {
            Description = 'Descripcion del articulo';
        }
        field(75; Quantity; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
            Editable = false;
        }
        field(80; "Qty. to Receive"; Decimal)
        {
            Caption = 'Qty. to Receive';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(90; "Unit of Measure"; Text[10])
        {
            Caption = 'Unit of Measure';
        }
        field(92; "Direct Unit Cost"; Decimal)
        {
            Description = 'Costo Unitario';
        }
        field(94; Amount; Decimal)
        {
            Description = 'Total Costo sin IVA';
        }
        field(96; "Amount Including VAT"; Decimal)
        {
            Description = 'Total Costo con IVA';
        }
        field(100; TransferComplete; Boolean)
        {
        }
        field(102; "Consolidado No."; Code[20])
        {
        }
        field(110; Received; Boolean)
        {
        }
        field(111; "Status NAV"; Option)
        {
            OptionCaption = 'New,Received,ReceiptCreated,ErrorValidation,CloseErasePurch,PurchNotExists,Canceled';
            OptionMembers = New,Received,ReceiptCreated,ErrorValidation,CloseErasePurch,PurchNotExists,Canceled;
        }
        field(112; "Description Error"; Text[50])
        {
            Description = 'Breve descripcion de error';
        }
        field(120; Rapidito; Boolean)
        {
        }
        field(130; "Order Type"; Option)
        {
            OptionCaption = 'Normal,Exclude';
            OptionMembers = Normal,Exclude;
        }
        field(452; "Replication Counter"; Integer)
        {

            trigger OnValidate()
            var
                FSNExternalPurchLine: Record "FSN External Purch. Line";
            begin
                FSNExternalPurchLine.RESET;
                FSNExternalPurchLine.SETCURRENTKEY("Replication Counter");
                IF FSNExternalPurchLine.FINDLAST THEN
                    "Replication Counter" := FSNExternalPurchLine."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;
        }
        field(453; "Status Purchase"; Enum "FSN Status Purchase Dev")
        {
        }
    }

    keys
    {
        key(Key1; "No.", "Line No.")
        {
            Clustered = true;
        }
        key(Key2; "Source No.", TransferComplete, Received, "Status NAV")
        {
        }
        key(Key3; "Replication Counter")
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnInsert()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnModify()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnRename()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnDelete()
    var
    begin
    end;
}

