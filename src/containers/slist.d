/**
 * Singly-linked list.
 * Copyright: © 2015 Economic Modeling Specialists, Intl.
 * Authors: Brian Schott
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */

module containers.slist;

private import containers.internal.node : shouldAddGCRange;
private import std.experimental.allocator.mallocator : Mallocator;

/**
 * Single-linked allocator-backed list.
 * Params:
 *     T = the element type
 *     Allocator = the allocator to use. Defaults to `Mallocator`.
 *     supportGC = true if the container should support holding references to
 *         GC-allocated memory.
 */
struct SList(T, Allocator = Mallocator, bool supportGC = shouldAddGCRange!T)
{
	/// Disable copying.
	this(this) @disable;

	private import std.experimental.allocator.common : stateSize;

	static if (stateSize!Allocator != 0)
	{
		/// No default construction if an allocator must be provided.
		this() @disable;

		/**
		 * Use the given `allocator` for allocations.
		 */
		this(Allocator allocator)
		in
		{
			assert(allocator !is null, "Allocator must not be null");
		}
		body
		{
			this.allocator = allocator;
		}
	}

	~this()
	{
		Node* current = _front;
		Node* prev = null;
		while (current !is null)
		{
			prev = current;
			current = current.next;
			typeid(Node).destroy(prev);
			static if (useGC)
			{
				import core.memory : GC;
				GC.removeRange(prev);
			}
			allocator.dispose(prev);
		}
		_front = null;
	}

	/**
	 * Returns: the most recently inserted item
	 */
	auto front(this This)() @property
	in
	{
		assert (!empty);
	}
	body
	{
		alias ET = ContainerElementType!(This, T);
		return cast(ET) _front.value;
	}

	/**
	 * Removes and returns the first item in the list.
	 */
	T moveFront()
	in
	{
		assert (!empty);
	}
	body
	{
		Node* f = _front;
		_front = f.next;
		T r = f.value;
		static if (useGC)
		{
			import core.memory : GC;
			GC.removeRange(f);
		}
		allocator.dispose(f);
		--_length;
		return r;
	}

	/**
	 * Removes the first item in the list.
	 */
	void popFront()
	{
		Node* f = _front;
		_front = f.next;
		static if (useGC)
		{
			import core.memory : GC;
			GC.removeRange(f);
		}
		allocator.dispose(f);
		--_length;
	}

	/**
	 * Returns: true if this list is empty
	 */
	bool empty() inout pure nothrow @property @safe @nogc
	{
		return _front is null;
	}

	/**
	 * Returns: the number of items in the list
	 */
	size_t length() inout pure nothrow @property @safe @nogc
	{
		return _length;
	}

	/**
	 * Inserts an item at the front of the list.
	 * Params: t = the item to insert into the list
	 */
	void insertFront(T t) @trusted
	{
		_front = make!Node(allocator, _front, t);
		static if (useGC)
		{
			import core.memory : GC;
			GC.addRange(_front, Node.sizeof);
		}
		_length++;
	}

	/// ditto
	alias insert = insertFront;

	/// ditto
	alias put = insertFront;

	/// Supports $(B list ~= item) syntax
	void opOpAssign(string op)(T t) if (op == "~")
	{
		put(t);
	}

	/**
	 * Removes the first instance of value found in the list.
	 * Returns: true if a value was removed.
	 */
	bool remove(V)(V value) @trusted
	{
		Node* prev = null;
		Node* cur = _front;
		while (cur !is null)
		{
			if (cur.value == value)
			{
				if (prev !is null)
					prev.next = cur.next;
				if (_front is cur)
					_front = cur.next;
				static if (shouldAddGCRange!T)
				{
					import core.memory : GC;
					GC.removeRange(cur);
				}
				allocator.dispose(cur);
				_length--;
				return true;
			}
			prev = cur;
			cur = cur.next;
		}
		return false;
	}

	/**
	 * Forward range interface
	 */
	auto range(this This)()
	{
		return Range!(This)(_front);
	}

	/// ditto
	alias opSlice = range;

	/**
	 * Removes all elements from the range
	 */
	void clear()
	{
		Node* prev = null;
		Node* cur = _front;
		while (cur !is null)
		{
			prev = cur;
			cur = prev.next;
			static if (shouldAddGCRange!T)
			{
				import core.memory : GC;
				GC.removeRange(prev);
			}
			allocator.dispose(prev);
		}
		_front = null;
		_length = 0;
	}

private:

	import std.experimental.allocator : make, dispose;
	import containers.internal.node : shouldAddGCRange;
	import containers.internal.element_type : ContainerElementType;
	import containers.internal.mixins : AllocatorState;

	enum bool useGC = supportGC && shouldAddGCRange!T;

	static struct Range(ThisT)
	{
	public:
		ET front() pure nothrow @property @trusted @nogc
		{
			return cast(typeof(return)) current.value;
		}

		void popFront() pure nothrow @safe @nogc
		{
			current = current.next;
		}

		bool empty() const pure nothrow @property @safe @nogc
		{
			return current is null;
		}

	private:
		alias ET = ContainerElementType!(ThisT, T);
		const(Node)* current;
	}

	static struct Node
	{
		Node* next;
		T value;
	}

	mixin AllocatorState!Allocator;
	Node* _front;
	size_t _length;
}

unittest
{
	import std.string : format;
	import std.algorithm : canFind;
	SList!int intList;
	foreach (i; 0 .. 100)
		intList.put(i);
	assert (intList.length == 100, "%d".format(intList.length));
	assert (intList.remove(10));
	assert (!intList.remove(10));
	assert (intList.length == 99);
	assert (intList.range.canFind(9));
	assert (!intList.range.canFind(10));
	SList!string l;
	l ~= "abcde";
	l ~= "fghij";
	assert (l.length == 2);
}
