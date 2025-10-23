import React from "react";
import { Image, ImageBackground, SafeAreaView, ScrollView, Text, TouchableOpacity, View, } from "react-native";
export default () => {
	return (
		<SafeAreaView 
			style={{
				flex: 1,
				backgroundColor: "#FFFFFF",
			}}>
			<ScrollView  
				style={{
					flex: 1,
					backgroundColor: "#FFFFFF",
				}}>
				<View 
					style={{
						flexDirection: "row",
						backgroundColor: "#FFFFFF",
						paddingVertical: 9,
						marginTop: 44,
						marginBottom: 16,
					}}>
					<Image
						source = {{uri: "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/Y6HTvlzwKN/rhi1pdml_expires_30_days.png"}} 
						resizeMode = {"stretch"}
						style={{
							width: 24,
							height: 24,
							marginLeft: 16,
							marginRight: 114,
						}}
					/>
					<Text 
						style={{
							color: "#000000",
							fontSize: 17,
							fontWeight: "bold",
						}}>
						{"Workout"}
					</Text>
				</View>
				<View 
					style={{
						marginBottom: 12,
						marginHorizontal: 14,
					}}>
					<View 
						style={{
							flexDirection: "row",
							justifyContent: "space-between",
							marginBottom: 32,
							marginHorizontal: 2,
						}}>
						<Text 
							style={{
								color: "#000000",
								fontSize: 12,
							}}>
							{"Warm-Up"}
						</Text>
						<View 
							style={{
								flexDirection: "row",
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									marginRight: 90,
								}}>
								{"Warm-Up Series C"}
							</Text>
							<Image
								source = {{uri: "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/Y6HTvlzwKN/72peeauy_expires_30_days.png"}} 
								resizeMode = {"stretch"}
								style={{
									width: 20,
									height: 20,
								}}
							/>
						</View>
					</View>
					<View 
						style={{
							flexDirection: "row",
							justifyContent: "space-between",
							marginBottom: 52,
							marginHorizontal: 2,
						}}>
						<Text 
							style={{
								color: "#000000",
								fontSize: 12,
							}}>
							{"Reps"}
						</Text>
						<View 
							style={{
								flexDirection: "row",
							}}>
							<View 
								style={{
									marginRight: 79,
								}}>
								<Text 
									style={{
										color: "#000000",
										fontSize: 14,
									}}>
									{"3 x 2 x 250’s @ 85%"}
								</Text>
							</View>
							<Image
								source = {{uri: "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/Y6HTvlzwKN/bvjit37u_expires_30_days.png"}} 
								resizeMode = {"stretch"}
								style={{
									width: 20,
									height: 20,
								}}
							/>
						</View>
					</View>
					<View 
						style={{
							flexDirection: "row",
							justifyContent: "space-between",
							marginBottom: 32,
							marginHorizontal: 2,
						}}>
						<Text 
							style={{
								color: "#000000",
								fontSize: 12,
							}}>
							{"Cooldown"}
						</Text>
						<View 
							style={{
								flexDirection: "row",
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									marginRight: 17,
								}}>
								{"Cooldown B Hurdle Mobility E"}
							</Text>
							<Image
								source = {{uri: "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/Y6HTvlzwKN/i6816azx_expires_30_days.png"}} 
								resizeMode = {"stretch"}
								style={{
									width: 20,
									height: 20,
								}}
							/>
						</View>
					</View>
					<View 
						style={{
							flexDirection: "row",
							marginBottom: 16,
							marginHorizontal: 2,
						}}>
						<Text 
							style={{
								color: "#000000",
								fontSize: 12,
								marginRight: 28,
							}}>
							{"Supplementals"}
						</Text>
						<View 
							style={{
								flex: 1,
								flexDirection: "row",
								justifyContent: "space-between",
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
								}}>
								{"Ice Bath + Quality Sleep"}
							</Text>
							<Image
								source = {{uri: "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/Y6HTvlzwKN/irjn7q55_expires_30_days.png"}} 
								resizeMode = {"stretch"}
								style={{
									width: 20,
									height: 20,
								}}
							/>
						</View>
					</View>
					<View 
						style={{
							flexDirection: "row",
							justifyContent: "space-between",
							marginBottom: 9,
							marginRight: 21,
						}}>
						<Text 
							style={{
								color: "#000000",
								fontSize: 20,
								fontWeight: "bold",
							}}>
							{"Rep(s)"}
						</Text>
						<Text 
							style={{
								color: "#000000",
								fontSize: 20,
								fontWeight: "bold",
							}}>
							{"Time"}
						</Text>
						<Text 
							style={{
								color: "#000000",
								fontSize: 20,
								fontWeight: "bold",
							}}>
							{"Rest"}
						</Text>
					</View>
					<View 
						style={{
							paddingTop: 5,
							paddingBottom: 8,
							paddingRight: 26,
							marginHorizontal: 2,
						}}>
						<View 
							style={{
								flexDirection: "row",
								alignItems: "center",
								marginBottom: 12,
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"250"}
							</Text>
							<View 
								style={{
									flex: 1,
								}}>
							</View>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									marginRight: 61,
								}}>
								{"Enter  time in (s)"}
							</Text>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"6 min"}
							</Text>
						</View>
						<View 
							style={{
								flexDirection: "row",
								alignItems: "center",
								marginBottom: 12,
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"250"}
							</Text>
							<View 
								style={{
									flex: 1,
								}}>
							</View>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									marginRight: 61,
								}}>
								{"Enter  time in (s)"}
							</Text>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"4 min"}
							</Text>
						</View>
						<View 
							style={{
								flexDirection: "row",
								alignItems: "center",
								marginBottom: 12,
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"250"}
							</Text>
							<View 
								style={{
									flex: 1,
								}}>
							</View>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									marginRight: 61,
								}}>
								{"Enter  time in (s)"}
							</Text>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"6 min"}
							</Text>
						</View>
						<View 
							style={{
								flexDirection: "row",
								alignItems: "center",
								marginBottom: 12,
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"250"}
							</Text>
							<View 
								style={{
									flex: 1,
								}}>
							</View>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									marginRight: 61,
								}}>
								{"Enter  time in (s)"}
							</Text>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"4 min"}
							</Text>
						</View>
						<View 
							style={{
								flexDirection: "row",
								alignItems: "center",
								marginBottom: 12,
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"250"}
							</Text>
							<View 
								style={{
									flex: 1,
								}}>
							</View>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									marginRight: 61,
								}}>
								{"Enter  time in (s)"}
							</Text>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"6 min"}
							</Text>
						</View>
						<View 
							style={{
								flexDirection: "row",
								alignItems: "center",
							}}>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"250"}
							</Text>
							<View 
								style={{
									flex: 1,
								}}>
							</View>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									marginRight: 61,
								}}>
								{"Enter  time in (s)"}
							</Text>
							<Text 
								style={{
									color: "#000000",
									fontSize: 14,
									fontWeight: "bold",
								}}>
								{"4 min"}
							</Text>
						</View>
					</View>
				</View>
				<Text 
					style={{
						color: "#000000",
						fontSize: 20,
						fontWeight: "bold",
						marginBottom: 12,
					}}>
					{"Countdown Timer"}
				</Text>
				<View 
					style={{
						flexDirection: "row",
						marginBottom: 19,
						marginHorizontal: 18,
					}}>
					<ImageBackground 
						source={{uri: "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/Y6HTvlzwKN/56auij2l_expires_30_days.png"}} 
						resizeMode = {'stretch'}
						style={{
							flex: 1,
							alignItems: "center",
							paddingTop: 75,
							paddingBottom: 77,
							marginRight: 22,
						}}
						>
						<Text 
							style={{
								color: "#000000",
								fontSize: 28,
							}}>
							{"00:4:02"}
						</Text>
					</ImageBackground>
					<Image
						source = {{uri: "https://storage.googleapis.com/tagjs-prod.appspot.com/v1/Y6HTvlzwKN/7cjepdlb_expires_30_days.png"}} 
						resizeMode = {"stretch"}
						style={{
							width: 109,
							height: 105,
							marginTop: 24,
						}}
					/>
				</View>
				<View 
					style={{
						backgroundColor: "#FFFFFF",
						paddingTop: 12,
						paddingBottom: 8,
						paddingHorizontal: 16,
					}}>
					<TouchableOpacity 
						style={{
							alignItems: "center",
							backgroundColor: "#34A853",
							borderRadius: 8,
							paddingVertical: 14,
							shadowColor: "#0000000D",
							shadowOpacity: 0.1,
							shadowOffset: {
							    width: 0,
							    height: 1
							},
							shadowRadius: 2,
							elevation: 2,
						}} onPress={()=>alert('Pressed!')}>
						<Text 
							style={{
								color: "#FFFFFF",
								fontSize: 16,
							}}>
							{"Complete Workout"}
						</Text>
					</TouchableOpacity>
				</View>
			</ScrollView>
		</SafeAreaView>
	)
}