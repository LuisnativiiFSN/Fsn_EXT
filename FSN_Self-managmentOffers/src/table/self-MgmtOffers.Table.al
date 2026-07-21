table 50016 "FSN Self-Mgmt Offers"
{
    Caption = 'Self-Management Offers';
    fields
    {
        field(1; "Offer Type"; Option)
        {
            Caption = 'Offer Type';
            OptionCaption = 'Base,Special Group,Banks';
            OptionMembers = "Base","Special Group","Banks";
        }
        field(2; Store; Code[20])
        {
            Caption = 'Store';
        }
        field(3; "start Date"; Date)
        {
            Caption = 'Start Date';
        }
        field(4; "End Date"; Date)
        {
            Caption = 'End Date';
        }
        field(5; Type; Option)
        {
            Caption = 'Type';
            OptionMembers = Item,"Special Group",All;
            OptionCaption = 'Item,Special Group,All';
        }
        field(6; "Item No."; Code[20])
        {
            Caption = 'Item No.';

            trigger OnValidate()
            begin
                case Type of
                    Type::Item:
                        begin
                            Item.Get("Item No.");
                            "Item Description" := Item.Description;
                        end;
                    Type::"Special Group":
                        begin
                            SpecialGroup.Get("Item No.");
                            "Item Description" := SpecialGroup.Description;
                        end;
                end;
            end;
        }
        field(7; "Item Description"; Text[100])
        {
            Caption = 'Item Description';
        }
        field(8; "unit Of Measure"; Code[20])
        {
            Caption = 'Unit Of Measure';
        }
        field(9; "% discount"; Decimal)
        {
            Caption = '% Discount';

            trigger OnValidate()
            begin
                if Item.Get("Item No.") then
                    Price := Item."Unit Price" * (1 - ("% discount" / 100));
            end;
        }
        field(10; Price; Decimal)
        {
            Caption = 'Price';

            trigger OnValidate()
            begin
                if Item.Get("Item No.") then
                    "% discount" := (Price / Item."Unit Price") * 100;
            end;
        }
        field(11; "discount Group"; Option)
        {
            Caption = 'Discount Group';
            OptionMembers = "RETAIL","VIP","FASANI","ADFSN";
            OptionCaption = 'RETAIL,VIP,FASANI,ADFSN';
        }
        field(12; "sell Out"; Boolean)
        {
            Caption = 'Sell Out';
        }
        field(13; "Sell Out Value"; Decimal)
        {
            Caption = 'Sell Out Value';
        }
        field(14; "Web category type"; Option)
        {
            Caption = 'Web Category Type';
            OptionMembers = "Nothing","Exists";
            OptionCaption = 'nothing,exists';
        }
        field(15; "Web Category name"; Code[20])
        {
            Caption = 'Web Category Name';
        }
        field(16; "Web category Start Date"; Date)
        {
            Caption = 'Web Category Start Date';
        }
        field(17; "Web category End Date"; Date)
        {
            Caption = 'Web Category End Date';
        }
        field(18; "Bank name"; Option)
        {
            Caption = 'Bank Name';
            OptionMembers = "Agricola","Cuscatlan","Promerica","Credisiman","Credicomer","Bac","Fedecredito","Hipotecario";
            OptionCaption = 'Agricola,Cuscatlan,Promerica,Credisiman,Credicomer,Bac,Fedecredito,Hipotecario';
        }
    }

    keys
    {
        key(PK; "Offer Type", Store, "start Date", "unit Of Measure", "Item No.")
        {
            Clustered = true;
        }
        key(search1; "Offer Type", Store, "start Date")
        {

        }
    }

    var
        Item: Record Item;
        SpecialGroup: Record "LSC Item Special Groups";

    trigger OnInsert()
    begin
        CreateActions(0);
    end;

    trigger OnModify()
    begin
        CreateActions(1);
    end;

    trigger OnDelete()
    begin
        //agregar algo de la codeunit
        CreateActions(2);
    end;

    local procedure CreateActions(Type: Integer)
    var
        RecRef: RecordRef;
        xRecRef: RecordRef;
        ActionMgmt: Codeunit "LSC Actions Management";
    begin
        // 0 = Create, 1 = Modify, 2 = Delete
        RecRef.GetTable(Rec);
        xRecRef.GetTable(xRec);
        ActionMgmt.SetCalledByTableTrigger(True);
        ActionMgmt.CreateActionsByRecRef(RecRef, xRecRef, Type);
    end;
}