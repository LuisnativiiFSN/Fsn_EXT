/// <summary>
/// Page FSN Check Totals (ID 50102).
/// </summary>
page 50102 "FSN Check Totals"
{
    PageType = StandardDialog;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "LSC P/R Counting Header";

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(SubTotal; SubTotal)
                {
                    trigger OnValidate()
                    begin
                        if validateDifference(SubTotal, originalSubTotal, differenceSubTotal) then
                            Total := SubTotal + Tax
                        else
                            SubTotal := originalSubTotal;
                    end;
                }
                field(Tax; Tax)
                {
                    trigger OnValidate()
                    begin
                        if validateDifference(Tax, originalTax, differenceTax) then
                            Total := SubTotal + Tax
                        else
                            Tax := originalTax;
                    end;
                }
                field(Total; Total)
                {
                    Editable = false;
                }
            }
        }
    }

    local procedure ValidateDifference(field: Decimal; originalValue: Decimal; Difference: Decimal): Boolean
    begin
        if (field < originalValue - Difference)
        or (field > originalValue + Difference) then begin
            Message('The value has changed more than %1 value.', Difference);
            exit(false);
        end;
        exit(true);
    end;

    trigger OnOpenPage();
    begin
        //? Save the original values
        originalSubTotal := SubTotal;
        originalTax := Tax;
        originalTotal := Total;
        //? Set the diference percent to 25%
        differenceTax := 0.10;
        differenceSubTotal := 1.00;
    end;

    var
        originalSubTotal, originalTax, originalTotal, differenceTax, differenceSubTotal : Decimal;
}