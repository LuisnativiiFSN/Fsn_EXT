pageextension 50075 "FSN ReplenTemplateCardExt" extends "LSC Replen. Template"
{
    layout
    {
        addafter(Filters)
        {
            group("FSN Filter")
            {
                Visible = false; //Temporal
                Caption = 'FSN Filter';
                field("FSN Item Hierarchy Level Filter"; "Item Hierarchy Level Filter")
                {
                    ApplicationArea = All;
                    BlankZero = true;
                    ToolTip = 'Specifies the item hierarchy level that will be used to filter the items.';
                }
                field("FSN Item Hierarchy Value Filter"; "Item Hierarchy Value Filter")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item hierarchy value that will be used to filter the items.';
                }
                field("FSN Special Group Code Filter"; "Special Group Code Filter")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the special group code that will be used to filter the items.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        lItemSpecialGroup: Record "LSC Item Special Groups";
                    begin
                        lItemSpecialGroup.Reset;
                        if PAGE.RunModal(0, lItemSpecialGroup) = ACTION::LookupOK then
                            if "Special Group Code Filter" <> '' then
                                "Special Group Code Filter" := "Special Group Code Filter" + '|' + lItemSpecialGroup.Code
                            else
                                "Special Group Code Filter" := lItemSpecialGroup.Code;
                    end;
                }
                field("FSN Item Attribute Code Filter"; "Item Attribute Code Filter")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item attribute code that will be used to filter the items.';
                }
                field("FSN Item Attribute Value Filter"; "Item Attribute Value Filter")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the item attribute value that will be used to filter the items.';
                }

            }
        }
        addafter("Total Cubage")
        {
            field("Associated Credit Memo"; "Associated Credit Memo")
            {
                Caption = 'Associated Credit Memo';
            }
        }
    }

    actions
    {
    }

}