report 50013 "FSN Bank Acc"
{
    DefaultLayout = RDLC;
    RDLCLayout = 'src/Report/Layout/FSNBankAccRecon.rdl';
    Caption = 'FSN Bank Acc Recon';
    ProcessingOnly = false;

    dataset
    {


        dataitem(ba; "Bank Account")
        {
            column(FORMAT_TODAY_0_4_; Format(Today, 0, 4)) { }
            column(COMPANYNAME; COMPANYPROPERTY.DisplayName) { }
            column(ba_Bank_Name; ba.Name) { }
            dataitem(bar; "Bank Acc. Reconciliation")
            {
                DataItemLink = "Bank Account No." = field("No.");
                column(bar_Statement_Ending_Balance; bar."Statement Ending Balance") { }
                column(bar_Statement_Date; bar."Statement Date") { }
                column(bar_Statement_No; StatementNoFilter) { }
                dataitem(bale; "Bank Account Ledger Entry")
                {
                    DataItemLink = "Bank Account No." = field("Bank Account No.");
                    DataItemTableView = SORTING("Bank Account No.");
                    column(bale_Bank_Account_No; bale."Bank Account No.") { }
                    column(bale_Statement_Status; bale."Statement Status") { }
                    column(bale_Posting_Date; bale."Posting Date") { }
                    column(bale_Document_No; bale."Document No.") { }
                    column(bale_Descriptcion; bale.Description) { }
                    column(bale_Credit_Amount; bale."Credit Amount") { }
                    column(bale_Debit_Amount; bale."Debit Amount") { }
                    column(bala_Sum_Credit; SumCredit) { }
                    column(bala_Sum_Debit; SumDebit) { }
                    column(AmountBale; AmountBale) { }
                    column(bala_Sum_AmountGLE; AmountGLE) { }
                    column(SumBarlAmountN; SumBarlAmountN) { }
                    column(SumBarlAmountS; SumBarlAmountS) { }
                    trigger OnPreDataItem()
                    var
                        barl: Record "Bank Acc. Reconciliation Line";
                    begin
                        AmountGLE := CalcBalanceToReconcile(BankAccountNoFilter, bar."Statement Date");
                        barl.SetRange("Bank Account No.", BankAccountNoFilter);
                        barl.SetRange("Statement No.", StatementNoFilter);
                        if barl.FindFirst() then
                            repeat begin
                                if barl."Applied Entries" = 0 then
                                    SumBarlAmountN += barl."Statement Amount"
                                else
                                    SumBarlAmountS += barl."Statement Amount";
                            end until barl.Next() = 0;
                        bale.SetFilter("Posting Date", '<=%1', bar."Statement Date");
                        if bale.FindFirst() then begin
                            repeat begin
                                if bale."Statement Status" = bale."Statement Status"::Open then begin
                                    SumCredit += bale."Credit Amount";
                                    SumDebit += bale."Debit Amount";
                                end else
                                    AmountBale += Amount;
                            end until bale.Next() = 0;
                        end;
                        //bale.SetRange("Statement Status", bale."Statement Status"::Open);
                        bale.SetRange(Reversed, false);
                        bale.SetAscending("Posting Date", true);
                        if bale.FindSet() then;
                    end;

                    trigger OnAfterGetRecord()
                    begin

                    end;


                }
                trigger OnPreDataItem()
                begin
                    StatementDate := bar."Statement Date";
                end;
            }
            trigger OnPreDataItem()
            begin
                ba.SetRange("No.", BankAccountNoFilter);
                if ba.FindFirst() then;
            end;
        }

    }
    requestpage
    {
        layout
        {
            area(content)
            {
                group(Group)
                {
                    field(AccountNo; BankAccountNoFilter)
                    {
                        ApplicationArea = All;
                    }
                    field(StatementNo; StatementNoFilter)
                    {
                        ApplicationArea = All;
                    }


                }
            }
        }

        actions
        {
        }
    }

    trigger OnPreReport()
    var
    begin

    end;


    var
        BankAccountNoFilter, StatementNoFilter : Code[20];
        SumCredit, SumDebit, AmountGLE, AmountBale, SumBarlAmountN, SumBarlAmountS : Decimal;
        StatementDate: Date;

    procedure CalcBalanceToReconcile(BankAccount: Code[20]; StatementDate: Date): Decimal
    var
        BankAccountLedgerEntry: Record "Bank Account Ledger Entry";
    begin
        BankAccountLedgerEntry.Reset();
        BankAccountLedgerEntry.SetRange("Bank Account No.", BankAccount);
        BankAccountLedgerEntry.SetFilter("Posting Date", '<=%1', StatementDate);
        BankAccountLedgerEntry.SetFilter("Statement Status", '%1|%2|%3', BankAccountLedgerEntry."Statement Status"::Open, BankAccountLedgerEntry."Statement Status"::"Bank Acc. Entry Applied", BankAccountLedgerEntry."Statement Status"::"Check Entry Applied");
        BankAccountLedgerEntry.SetRange(Reversed, false);
        BankAccountLedgerEntry.SetRange(Open, true);
        BankAccountLedgerEntry.CalcSums(Amount);
        exit(BankAccountLedgerEntry.Amount);
    end;

}

