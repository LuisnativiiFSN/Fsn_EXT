page 50118 "FSN Purchase Excepcion List"
{

    ApplicationArea = All;
    Caption = 'FSN Purchase Excepcions';
    CardPageID = "FSN Purchase Excepcion Card";
    Editable = false;
    PageType = List;
    PromotedActionCategories = 'Purchase Excepcion';
    RefreshOnActivate = true;
    SourceTable = "FSN Purchase Excepcion";
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Control1)
            {
                ShowCaption = false;

                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = '';
                }
                field("LSC Attrib 1 Code"; Rec."LSC Attrib 1 Code")
                {
                    Caption = 'Laboratory';
                }
                field("Purch. Unit of Measure"; Rec."Purch. Unit of Measure")
                {
                    ApplicationArea = All;
                    ToolTip = '';
                }
                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = '';
                }


                field("Use Priority Attrib 1 Code"; Rec."Use Priority Attrib 1 Code")
                {
                    Caption = 'Use Priority Laboratory';
                }

                field("Active From Date"; Rec."Active From Date")
                {
                    Caption = 'Active From Date';
                }
                field("Active To Date"; Rec."Active To Date")
                {
                    Caption = 'Active To Date';
                }
                field("Type Control"; Rec."Type Control")
                {
                    Caption = 'Type Control';
                }

                field("Range Lim. Point Reorder"; Rec."Range Lim. Point Reorder")
                {
                    Caption = 'Range Lim. Point Reorder';
                }

                field("Range Lim. Max Stock"; Rec."Range Lim. Max Stock")
                {
                    Caption = 'Range Lim. Max Stock';
                }
                field("Manual Reorder Point"; Rec."Manual Reorder Point")
                {
                    Caption = 'Manual Reorder Point';
                }
                field("Max Manual Stock"; Rec."Max Manual Stock")
                {
                    Caption = 'Maximum Manual Stock';
                }

                field("Reorder time Min. Man (Days)"; Rec."Reorder time Min. Man (Days)")
                {
                    Caption = 'Reorder time Min. Man (Days)';
                }

                field("Reorder time. Max. Man (Days)"; Rec."Reorder time Max. Man (Days)")
                {
                    Caption = 'Reorder time. Max. Man (Days)';
                }

                field("Time Reorder Lim. (Days)"; Rec."Time Reorder Lim. (Days)")
                {
                    Caption = 'Time Reorder Lim. (Days)';
                }
                field("Definition Exception"; Rec."Definition Exception")
                {
                    Caption = 'Definition Exception';
                }

            }

        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction()
                begin

                end;
            }
        }
    }

    var
        ItemNoList: Code[50];



}

