pageextension 50035 "FSN Income/Expense Acc. Card" extends "LSC Income/Expense Acc. card"
{
    layout
    {
        addafter(General)
        {
            group(FSN)
            {
                field("Only Ticket"; "Only Ticket")
                {
                    ApplicationArea = All;
                    Caption = 'Only Ticket';
                    ToolTip = 'Only Ticket';
                }
                field("Locked in Sales"; "Locked in Sales")
                {
                    ApplicationArea = All;
                    Caption = 'Locked in Sales';
                    ToolTip = 'Locked in Sales';
                }
                field(paymentIn; paymentIn)
                {
                    ApplicationArea = All;
                    Caption = 'Payment in';
                    ToolTip = 'Payment in';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        tenderType: Record "LSC Tender Type";
                        tenderTypeList: Page "LSC Tender Type List";
                    begin
                        tenderType.SetFilter("Store No.", Rec."Store No.");
                        tenderTypeList.SetTableView(tenderType);
                        tenderTypeList.LookupMode(true);
                        if tenderTypeList.RunModal() = Action::LookupOK then begin
                            tenderTypeList.GetRecord(tenderType);
                            if Text = '' then
                                Text := tenderType.Code
                            else
                                Text += '|' + tenderType.Code;
                            tenderType.SetFilter(Code, Text);
                            exit(true);
                        end else
                            exit(false);
                    end;

                    trigger OnValidate()
                    var
                        tenderType: Record "LSC Tender Type";
                    begin
                        tenderType.SetFilter(Code, paymentIn);
                        if tenderType.Count = 0 then begin
                            Error('Tender type %1 does not exist.', paymentIn);
                            paymentIn := '';
                        end;
                        Rec."Payment in" := paymentIn;
                    end;
                }
            }
        }
    }
    var
        paymentIn: Code[250];

    trigger OnOpenPage()
    begin
        paymentIn := Rec."Payment in";
    end;
}