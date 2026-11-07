<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

## Trading deliverables
- PontoD Trendline revisions use one guarded executor for manual and automatic orders; account+magic daily accounting and exposure are shared across symbols to prevent inconsistent sizing and concurrent risk allocation. Pure rule tests compile extracted helpers only, not MQL5 or broker execution.
- Keep standalone trading deliverables separate from website code; a trading-file request does not change the sales page.
- The new confluence EA manages only its configured magic number across all symbols and requires a USD account, preventing interference with unrelated trades and ambiguous currency conversion.
- Use a TradingView Pine companion for manual IQ Option signals rather than credential-bearing unofficial APIs; broker quotes can differ and no orders are sent.
