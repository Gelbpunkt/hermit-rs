/// Prints dashed line
fn print_line() {
	log::info!("\n-------------------------------------------------------------\n");
}

/// Nicely outputs summary of execution with stats and CDF points.
pub fn print_summary(hist: hdrhist::HDRHist) {
	log::info!("Sent/received everything!");
	print_line();
	log::info!("HDRHIST summary, measure in ns");
	print_line();
	log::info!("summary:\n{:#?}", hist.summary().collect::<Vec<_>>());
	print_line();
	log::info!("Summary_string:\n{}", hist.summary_string());
	print_line();
	log::info!("CDF summary:\n");
	for entry in hist.ccdf_upper_bound() {
		log::info!("{entry:?}");
	}
}
