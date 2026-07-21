page 50093 "FSN Select Remission Tempory"
{
    Caption = 'Remission List';
    Editable = false;
    PageType = List;
    SourceTable = "FSN Remission Header";
    SourceTableTemporary = true;


    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; "No.")
                {
                }
                field("Company No."; "Company No.")
                {
                }
                field("Insured Name"; "Insured Name")
                {
                }
                field("External Document No."; "External Document No.")
                {
                }
                field("Amount Including VAT"; "Amount Including VAT")
                {
                }
                field(Status; Status)
                {
                    Style = Attention;
                    StyleExpr = (Status = 0);
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Procesar)
            {
                Image = Approve;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    FSNRemissionControl: Codeunit "FSN POS Remission Controller";
                    POSTransaction: Codeunit "LSC POS Transaction";
                    lPOSTransaction: Record "LSC POS Transaction";
                    RemissionHeaderTemp: Record "FSN Remission Header";
                begin
                    case RemissionLook of
                        'REMISSION_CO':
                            begin
                                if POSGUI.PosConfirm(StrSubstNo(Text000, Rec."No."), True) then begin
                                    FSNRemissionControl.InsertRemissionCo(Rec."No.", POSTransaction.GetReceiptNo());
                                    CurrPage.Close();
                                end;
                            end;

                        'REMISSION_FACT':
                            begin
                                CurrPage.SETSELECTIONFILTER(RemissionHeaderTemp);
                                if RemissionHeaderTemp.Find('-') then begin
                                    repeat
                                        FSNRemissionControl.InsertRemissionInvoice(RemissionHeaderTemp."No.", POSTransaction.GetReceiptNo());
                                    until RemissionHeaderTemp.Next() = 0;
                                    CurrPage.Close();
                                end;
                            end;
                    end;
                    if RemissionLook <> 'REMISSION_CO' then
                        if lPOSTransaction.get(POSTransaction.GetReceiptNo()) then begin
                            lPOSTransaction."FSN Remission No." := true;
                            lPOSTransaction.Modify();
                        end;
                end;
            }
        }
    }

    var
        myInt: Integer;
        POSGUI: Codeunit "LSC POS GUI";
        Text000: Label 'N° copago %1, desea continuar?';
        RemissionLook: Code[20];

    trigger OnClosePage()
    begin
        RemissionLook := '';
    end;

    procedure SETGLOBALVALUE(RemissionHeader: Record "FSN Remission Header" temporary; RemisLook: Code[20])
    begin
        Rec.Init();
        Rec := RemissionHeader;
        Rec.Insert();

        RemissionLook := RemisLook;


    end;

}