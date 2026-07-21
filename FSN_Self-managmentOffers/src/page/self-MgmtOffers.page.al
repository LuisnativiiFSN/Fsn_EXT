page 50071 "FSN Self-Mgmt Offers"
{
    Caption = 'FSN Self-Mgmt Offers';
    SourceTable = "FSN Self-Mgmt Offers";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            group("Filter")
            {
                Caption = 'Filter';
                field("Mass load per laboratory"; Filter)//campo de busqueda
                {
                    TableRelation = "LSC Attribute Option Value";
                    Caption = 'Mass load per laboratory';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        AttributeValue.SetRange("Attribute Code", 'LABORATORIO');
                        Action_l := Page.RunModal(Page::"LSC Attribute Option Value Lst", AttributeValue);
                        if Action_l = Action::LookupOK then
                            Filter := AttributeValue."Option Value";
                    end;
                }
            }
            group("data")
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
                    field("Web Category name"; Rec."Web Category name")
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
                }
            }
        }
    }
    actions
    {
        area(Processing)
        {
            action("Mass load")
            {
                Caption = 'Mass load';
                Image = Add;
                trigger OnAction()
                begin
                    if Filter = '' then
                        Error(gText001);

                    Item.Reset();
                    Item.SetRange("LSC Attrib 1 Code", Filter);

                    if Item.Find('-') then
                        repeat
                            Rec."Offer Type" := Rec."Offer Type"::"Special Group";
                            Rec."start date" := TODAY;
                            Rec.Type := Rec.Type::Item;
                            Rec.Validate("Item No.", Item."No.");
                            Rec."Unit of Measure" := Item."Base Unit of Measure";
                            Rec.Insert(true);
                        until Item.Next() = 0;
                end;
            }
            action("Confirm Offer")
            {
                Caption = 'Confirm Offer';
                Image = Apply;
                trigger OnAction()
                begin
                    if Rec.Find('-') then
                        repeat
                            OfferMgmt.Init();
                            OfferMgmt.TransferFields(Rec);
                            OfferMgmt.Insert(true);
                        until Rec.Next() = 0;

                    Rec.Reset();
                end;
            }
            action("Check Record")
            {
                Caption = 'Check Record';
                Image = Register;
                RunObject = Page "FSN Self-Mgmt Offers Record";
            }
        }
    }
    var
        AttributeValue: Record "LSC Attribute Option Value";
        OfferMgmt: Record "FSN Self-Mgmt Offers";
        Item: Record Item;
        Filter: Text[50];
        Action_l: Action;
        gText001: Label 'You must select a laboratory';

}