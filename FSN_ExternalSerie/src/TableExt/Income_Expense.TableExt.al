/// <summary>
/// TableExtension FSN Icome/Expense Account (ID 50064) extends Record LSC Income/Expense Account.
/// </summary>
tableextension 50064 "FSN Icome/Expense Account" extends "LSC Income/Expense Account"
{
    fields
    {
        field(300; "Only Ticket"; Boolean)
        {
            Caption = 'Only Ticket';
        }
        field(310; "Locked in Sales"; Boolean)
        {
            Caption = 'Locked in Sales';
        }
        field(320; "Payment in"; code[250])
        {
            Caption = 'Payment in';
            TableRelation = "LSC Tender Type";
            ValidateTableRelation = false;

            trigger OnValidate()
            begin
                if xRec."Payment in" <> '' then
                    Rec."Payment in" := xRec."Payment in" + '|' + Rec."Payment in";
            end;
        }

        field(330; "FSN Retention"; Boolean)
        {
            Caption = 'FSN Retention';
        }
        field(340; "FSN Perception"; Boolean)
        {
            Caption = 'FSN Perception';
        }
    }
}