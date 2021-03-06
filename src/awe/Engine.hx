package awe;
#if macro
import haxe.macro.Context;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using haxe.macro.ExprTools;
using awe.util.MacroTools;
import haxe.macro.Expr;
#end
import haxe.io.Bytes;
import awe.util.Timer;
import awe.util.Bag;
import awe.util.BitSet;
using awe.util.MoreStringTools;
import awe.ComponentList;
#if doc
	@:extern interface Injector {
		public function injectInto(v: Dynamic): Void;
	}
#else
	import minject.Injector;
#end

/**
	The central type of `Engine`.
**/
class Engine {
	/** The component lists for each type of `Component`. **/
	public var components(default, null): Map<ComponentType, IComponentList>;
	/** The systems to run. **/
	public var systems(default, null): Bag<System>;
	/** The managers. **/
	public var managers(default, null): Bag<Manager>;
	/** The entities that the systems run on. **/
	public var entities(default, null): Bag<Entity>;
	/** The composition of each entity. **/
	public var compositions(default, null): Map<Entity, BitSet>;
	/** How many entities have been created so far. **/
	public var entityCount(default, null): Int;
	/** This is used to inject the `IComponentList` into the `System`s. **/
	public var injector(default, null):Injector;

	/** 
		Construct a new engine.
		Note: `Engine.build` should be preferred.
		@param components The component lists for each type of `Component`.
		@param systems The systems to run.
		@param injector This is used to inject the `IComponentList` into the `System`s.
	**/
	public function new(components, systems, managers, injector) {
		this.components = components;
		this.systems = systems;
		this.managers = managers;
		this.injector = injector;
		entities = new Bag();
		compositions = new Map();
		entityCount = 0;
		for(system in systems)
			system.initialize(this);
		for(manager in managers)
			manager.initialize(this);
	}
	public static macro function build(setup: ExprOf<EngineSetup>): ExprOf<Engine> {
		var debug = Context.defined("debug");
		if(debug)
			Sys.println("Setting up Engine..");
		var expectedCount: Null<Int> = setup.getField("expectedEntityCount").getValue();
		var components = [for(component in setup.assertField("components").getArray()) {
			var cty = ComponentType.get(component.resolveTypeLiteral());
			var list = if(cty.isEmpty())
				macro null;
			else if(cty.isPacked())
				macro awe.ComponentList.PackedComponentList.build($component);
			else
				macro new awe.ComponentList($v{expectedCount});
			macro $v{cty.getPure()} => $list;
		}];
		var systems = setup.assertField("systems").getArray();
		var managers = setup.assertField("managers").getArray();
		var components = { expr: ExprDef.EArrayDecl(components), pos: setup.pos };
		var block = [
			(macro var components:Map<awe.ComponentType, awe.ComponentList.IComponentList> = $components),
			(macro var systems:awe.util.Bag<awe.System> = new awe.util.Bag($v{systems.length})),
			(macro var managers:awe.util.Bag<awe.Manager> = new awe.util.Bag($v{managers.length})),
			(macro var csystem:awe.System = null),
			(macro var cmanager:awe.Manager = null),
			macro var injector = new minject.Injector()
		];
		for(system in systems) {
			var ty = Context.typeof(system);
			block.push(macro systems.add(csystem = $system));
			block.push(macro injector.mapType($v{ty.toString()}, csystem).toValue(csystem));
		}
		for(manager in managers) {
			var ty = Context.typeof(manager);
			block.push(macro managers.add(cmanager = $manager));
			block.push(macro injector.mapType($v{ty.toString()}, cmanager).toValue(cmanager));
		}
		for(component in setup.assertField("components").getArray()) {
			var cty = ComponentType.get(component.resolveTypeLiteral());
			var parts = component.toString().split(".");
			var name = parts[parts.length - 1].toLowerCase().pluralize();
			block.push(macro injector.mapType('awe.IComponentList', $v{name}).toValue(components.get($v{cty.getPure()})));
		}
		block.push(macro new Engine(components, systems, managers, injector));
		var expr = {
			expr: ExprDef.EBlock(block),
			pos: Context.currentPos()
		};
		return expr;
	}
	/**
		Update all the `System`s contained in this.
		@param delta The change in time (in seconds).
	**/
	public inline function update(delta: Float)
		for(system in systems)
			if(system.shouldProcess())
				system.update(delta);

	/**
		Automatically run all the `System`s at a given interval.
		@param interval The interval to run the systems at (in seconds).
		@return The timer that has been created to run this.
	**/
	public function delayLoop(interval: Float): Timer {
		var timer = new Timer(Std.int(interval * 1000));
		timer.run = update.bind(interval);
		return timer;
	}
	public function loop() {
		var last = Timer.stamp();
		var curr = last;
		while(true) {
			curr = Timer.stamp();
			update(curr - last);
			last = curr;
		}
	}
}
typedef EngineSetup = {
	?expectedEntityCount: Int,
	?components: Array<Class<Component>>,
	?systems: Array<System>,
	?managers: Array<Manager>
}